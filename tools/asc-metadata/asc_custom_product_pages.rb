#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "pathname"
require "securerandom"
require "uri"
require "yaml"

require_relative "asc_metadata"

module ASCCustomProductPages
  class Error < StandardError; end

  class Runner
    def initialize(argv)
      @options = {
        app_id: ENV["ASC_APP_ID"] || ASCMetadata::DEFAULT_APP_ID,
        version: ENV["ASC_VERSION"] || ASCMetadata::DEFAULT_VERSION,
        config_path: ASCMetadata::DEFAULT_METADATA_CONFIG,
        apply: false
      }
      parse_options(argv)
    end

    def run
      config = load_config
      pages = Array(config["custom_product_pages"])
      raise Error, "No custom_product_pages configured in #{@options[:config_path]}" if pages.empty?

      template = ios_template!
      existing = custom_product_pages
      mode = @options[:apply] ? "APPLY" : "DRY-RUN"
      puts "#{mode}: custom product pages for app #{@options[:app_id]}, iOS #{@options[:version]}"

      pages.each do |page_config|
        name = page_config.fetch("name").to_s.strip
        texts = page_config.fetch("promotional_text").to_h
        validate_page!(name, texts)
        current = existing.find { |page| page.dig("attributes", "name") == name }
        if current
          puts "  #{name}: exists id=#{current["id"]} url=#{current.dig("attributes", "url")}"
          print_page_version(current["id"], texts)
        elsif @options[:apply]
          created = create_page(template["id"], name, texts)
          puts "  #{name}: created id=#{created["id"]} url=#{created.dig("attributes", "url")}"
        else
          puts "  #{name}: create from template #{template["id"]} with locales #{texts.keys.join(", ")}"
        end
      end

      print_campaign_links(config)
    end

    private

    def parse_options(argv)
      OptionParser.new do |opts|
        opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
        opts.on("--app-id APPLE_ID") { |value| @options[:app_id] = value }
        opts.on("--version VERSION") { |value| @options[:version] = value }
        opts.on("--config PATH") { |value| @options[:config_path] = value }
        opts.on("--apply", "Create missing pages. Omit for dry-run.") { @options[:apply] = true }
        opts.on("-h", "--help") { puts opts; exit 0 }
      end.parse!(argv)
    end

    def load_config
      path = Pathname(@options[:config_path])
      raise Error, "Metadata config not found: #{path}" unless path.file?

      YAML.safe_load(path.read, aliases: true) || {}
    rescue Psych::SyntaxError => e
      raise Error, "Invalid metadata YAML #{path}: #{e.message}"
    end

    def client
      @client ||= ASCMetadata::Client.new(
        issuer_id: required_env("ASC_ISSUER_ID"),
        key_id: required_env("ASC_KEY_ID"),
        private_key_pem: File.read(required_env("ASC_PRIVATE_KEY_PATH"))
      )
    end

    def required_env(name)
      value = ENV[name].to_s.strip
      raise Error, "Missing #{name}." if value.empty?

      value
    end

    def ios_template!
      versions = client.collection(
        "/v1/apps/#{@options[:app_id]}/appStoreVersions",
        "filter[versionString]" => @options[:version],
        "filter[platform]" => "IOS",
        "limit" => "20"
      )
      template = versions.find { |version| version.dig("attributes", "platform") == "IOS" }
      raise Error, "No iOS #{@options[:version]} App Store version found." unless template

      template
    end

    def custom_product_pages
      client.collection(
        "/v1/apps/#{@options[:app_id]}/appCustomProductPages",
        "fields[appCustomProductPages]" => "name,url,visible,appCustomProductPageVersions",
        "limit" => "200"
      )
    end

    def validate_page!(name, texts)
      raise Error, "Custom product page name is empty." if name.empty?
      raise Error, "#{name}: promotional_text is empty." if texts.empty?

      texts.each do |locale, text|
        length = text.to_s.length
        raise Error, "#{name} #{locale}: promotional text is empty." if length.zero?
        raise Error, "#{name} #{locale}: promotional text is #{length}/170 characters." if length > 170
      end
    end

    def create_page(template_id, name, texts)
      version_id = "${version-#{SecureRandom.uuid}}"
      localization_ids = texts.transform_values { "${localization-#{SecureRandom.uuid}}" }
      payload = {
        "data" => {
          "type" => "appCustomProductPages",
          "attributes" => { "name" => name },
          "relationships" => {
            "app" => { "data" => { "type" => "apps", "id" => @options[:app_id] } },
            "appStoreVersionTemplate" => { "data" => { "type" => "appStoreVersions", "id" => template_id } },
            "appCustomProductPageVersions" => {
              "data" => [{ "type" => "appCustomProductPageVersions", "id" => version_id }]
            }
          }
        },
        "included" => [
          {
            "type" => "appCustomProductPageVersions",
            "id" => version_id,
            "relationships" => {
              "appCustomProductPageLocalizations" => {
                "data" => localization_ids.values.map do |id|
                  { "type" => "appCustomProductPageLocalizations", "id" => id }
                end
              }
            }
          },
          *texts.map do |locale, promotional_text|
            {
              "type" => "appCustomProductPageLocalizations",
              "id" => localization_ids.fetch(locale),
              "attributes" => { "locale" => locale, "promotionalText" => promotional_text }
            }
          end
        ]
      }
      client.post("/v1/appCustomProductPages", payload).fetch("data")
    end

    def print_page_version(page_id, expected_texts)
      versions = client.collection(
        "/v1/appCustomProductPages/#{page_id}/appCustomProductPageVersions",
        "fields[appCustomProductPageVersions]" => "version,state,deepLink,appCustomProductPageLocalizations",
        "limit" => "20"
      )
      version = versions.max_by { |item| item.dig("attributes", "version").to_i }
      return puts("    no version found") unless version

      localizations = client.collection(
        "/v1/appCustomProductPageVersions/#{version["id"]}/appCustomProductPageLocalizations",
        "fields[appCustomProductPageLocalizations]" => "locale,promotionalText",
        "limit" => "200"
      )
      actual = localizations.to_h { |item| [item.dig("attributes", "locale"), item.dig("attributes", "promotionalText")] }
      matches = expected_texts.all? { |locale, text| actual[locale] == text }
      puts "    version=#{version.dig("attributes", "version")} state=#{version.dig("attributes", "state")} locales=#{actual.keys.sort.join(",")} copy=#{matches ? "match" : "DIFF"}"
    end

    def print_campaign_links(config)
      campaign_config = config.fetch("campaign_links", {}).to_h
      provider_token = campaign_config.fetch("provider_token", "").to_s.strip
      campaigns = Array(campaign_config["campaigns"])
      return if provider_token.empty? || campaigns.empty?

      puts
      puts "Campaign Links"
      campaigns.each do |campaign|
        token = URI.encode_www_form_component(campaign.to_s)
        puts "  #{campaign}: https://apps.apple.com/app/apple-store/id#{@options[:app_id]}?pt=#{provider_token}&ct=#{token}&mt=8"
      end
    end
  end
end

begin
  ASCCustomProductPages::Runner.new(ARGV).run
rescue ASCCustomProductPages::Error, ASCMetadata::Error => e
  warn "error: #{e.message}"
  exit 1
rescue OptionParser::InvalidOption => e
  warn "error: #{e.message}"
  exit 1
end
