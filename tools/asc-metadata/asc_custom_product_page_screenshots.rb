#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "optparse"
require "pathname"
require "yaml"

require_relative "asc_metadata"
require_relative "asc_screenshot_upload"

module ASCCustomProductPageScreenshots
  DISPLAY_CONFIG = {
    "iphone" => ["APP_IPHONE_65", "ios"],
    "ipad" => ["APP_IPAD_PRO_3GEN_129", "ipad"]
  }.freeze
  LOCALE_DIRECTORIES = {
    "en-US" => "en",
    "zh-Hans" => "zh-Hans",
    "zh-Hant" => "zh-Hant",
    "ja" => "ja",
    "ko" => "ko"
  }.freeze

  class Error < StandardError; end

  class Runner
    def initialize(argv)
      @options = {
        app_id: ENV["ASC_APP_ID"] || ASCMetadata::DEFAULT_APP_ID,
        config_path: ASCMetadata::DEFAULT_METADATA_CONFIG,
        root: "tools/appstore-screenshots/output/store",
        pages: [],
        locales: [],
        displays: [],
        timeout_seconds: 600,
        poll_seconds: 5,
        apply: false
      }
      parse_options(argv)
    end

    def run
      configs = selected_page_configs
      validate_assets!(configs)
      pages = custom_product_pages
      mode = @options[:apply] ? "APPLY" : "DRY-RUN"
      puts "#{mode}: custom product page screenshot ordering for app #{@options[:app_id]}"

      configs.each do |page_config|
        name = page_config.fetch("name")
        page = pages.find { |item| item.dig("attributes", "name") == name }
        raise Error, "Missing custom product page: #{name}" unless page

        version = current_version(page["id"])
        state = version.dig("attributes", "state")
        raise Error, "#{name}: version is not editable (state=#{state})" unless state == "PREPARE_FOR_SUBMISSION"

        puts
        puts "PAGE #{name} id=#{page["id"]} version=#{version.dig("attributes", "version")} state=#{state}"
        localizations(version["id"]).each do |localization|
          locale = localization.dig("attributes", "locale")
          next unless selected?(@options[:locales], locale)

          locale_dir = LOCALE_DIRECTORIES[locale]
          next unless locale_dir

          puts "  LOCALE #{locale} id=#{localization["id"]}"
          screenshot_plan(page_config).each do |display_key, stems|
            next unless selected?(@options[:displays], display_key)

            display_type, asset_dir = DISPLAY_CONFIG.fetch(display_key)
            files = stems.map { |stem| asset_path(asset_dir, locale_dir, stem) }
            sync_set(localization["id"], display_type, display_key, files)
          end
        end
      end
    end

    private

    def parse_options(argv)
      OptionParser.new do |opts|
        opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
        opts.on("--app-id APPLE_ID") { |value| @options[:app_id] = value }
        opts.on("--config PATH") { |value| @options[:config_path] = value }
        opts.on("--root PATH") { |value| @options[:root] = value }
        opts.on("--page NAME", "Restrict page; repeatable") { |value| @options[:pages] << value }
        opts.on("--locale LOCALE", "Restrict locale; repeatable") { |value| @options[:locales] << value }
        opts.on("--display TYPE", "iphone or ipad; repeatable") { |value| @options[:displays] << value }
        opts.on("--timeout-seconds N", Integer) { |value| @options[:timeout_seconds] = value }
        opts.on("--poll-seconds N", Integer) { |value| @options[:poll_seconds] = value }
        opts.on("--apply", "Replace nonmatching screenshot sets") { @options[:apply] = true }
        opts.on("-h", "--help") { puts opts; exit 0 }
      end.parse!(argv)

      invalid = @options[:displays] - DISPLAY_CONFIG.keys
      raise Error, "Unsupported display(s): #{invalid.join(", ")}" unless invalid.empty?
    end

    def config
      @config ||= YAML.safe_load(Pathname(@options[:config_path]).read, aliases: true) || {}
    rescue Errno::ENOENT
      raise Error, "Metadata config not found: #{@options[:config_path]}"
    rescue Psych::SyntaxError => e
      raise Error, "Invalid metadata YAML: #{e.message}"
    end

    def selected_page_configs
      configs = Array(config["custom_product_pages"])
      configs = configs.select { |item| selected?(@options[:pages], item["name"]) }
      raise Error, "No matching custom product pages in #{@options[:config_path]}" if configs.empty?

      configs
    end

    def screenshot_plan(page_config)
      plan = page_config.fetch("screenshots", {}).to_h
      missing = DISPLAY_CONFIG.keys - plan.keys
      raise Error, "#{page_config["name"]}: missing screenshot plan for #{missing.join(", ")}" unless missing.empty?

      plan
    end

    def validate_assets!(configs)
      configs.each do |page_config|
        screenshot_plan(page_config).each do |display_key, stems|
          raise Error, "#{page_config["name"]} #{display_key}: screenshot order is empty" if Array(stems).empty?
          raise Error, "#{page_config["name"]} #{display_key}: duplicate screenshot stems" if stems.uniq.length != stems.length

          LOCALE_DIRECTORIES.each_value do |locale_dir|
            _display_type, asset_dir = DISPLAY_CONFIG.fetch(display_key)
            stems.each do |stem|
              path = asset_path(asset_dir, locale_dir, stem)
              raise Error, "Missing screenshot asset: #{path}" unless path.file?
            end
          end
        end
      end
    end

    def asset_path(asset_dir, locale_dir, stem)
      Pathname(@options[:root]).join(asset_dir, locale_dir, "#{stem}.png")
    end

    def selected?(selection, value)
      selection.empty? || selection.include?(value)
    end

    def client
      @client ||= ASCMetadata::Client.new(
        issuer_id: required_env("ASC_ISSUER_ID"),
        key_id: required_env("ASC_KEY_ID"),
        private_key_pem: File.read(required_env("ASC_PRIVATE_KEY_PATH"))
      )
    end

    def direct_client
      @direct_client ||= ASCScreenshotUpload::DirectClient.new(client)
    end

    def required_env(name)
      value = ENV[name].to_s.strip
      raise Error, "Missing #{name}." if value.empty?

      value
    end

    def custom_product_pages
      client.collection(
        "/v1/apps/#{@options[:app_id]}/appCustomProductPages",
        "fields[appCustomProductPages]" => "name,url,visible,appCustomProductPageVersions",
        "limit" => "200"
      )
    end

    def current_version(page_id)
      versions = client.collection(
        "/v1/appCustomProductPages/#{page_id}/appCustomProductPageVersions",
        "fields[appCustomProductPageVersions]" => "version,state,appCustomProductPageLocalizations",
        "limit" => "20"
      )
      version = versions.max_by { |item| item.dig("attributes", "version").to_i }
      raise Error, "Custom product page #{page_id} has no version" unless version

      version
    end

    def localizations(version_id)
      client.collection(
        "/v1/appCustomProductPageVersions/#{version_id}/appCustomProductPageLocalizations",
        "fields[appCustomProductPageLocalizations]" => "locale,promotionalText,appScreenshotSets",
        "limit" => "200"
      ).sort_by { |item| item.dig("attributes", "locale").to_s }
    end

    def sync_set(localization_id, display_type, display_key, files)
      set = find_or_create_set(localization_id, display_type)
      existing = screenshots(set["id"])
      expected = files.map { |file| Digest::MD5.file(file).hexdigest }
      actual = existing.map { |item| item.dig("attributes", "sourceFileChecksum").to_s }
      order = files.map { |file| file.basename(".png").to_s }
      puts "    #{display_key}: #{order.join(" > ")}"

      if actual == expected && complete?(existing)
        puts "      SKIP ordered checksums match"
        return
      end

      if actual.take(expected.length) == expected && existing.length > expected.length && complete?(existing)
        stale_tail = existing.drop(expected.length)
        if @options[:apply]
          stale_tail.each { |item| direct_client.delete("/v1/appScreenshots/#{item["id"]}") }
          verified = wait_for_set(set["id"], files.length)
          checksums = verified.map { |item| item.dig("attributes", "sourceFileChecksum").to_s }
          raise Error, "#{display_key}: tail trim completed with unexpected screenshot order" unless checksums == expected

          puts "      trimmed #{stale_tail.length} off-theme tail screenshot(s); order=match"
        else
          puts "      would trim #{stale_tail.length} off-theme tail screenshot(s)"
        end
        return
      end

      if @options[:apply]
        existing.each { |item| direct_client.delete("/v1/appScreenshots/#{item["id"]}") }
        puts "      deleted #{existing.length} existing screenshot(s)" if existing.any?
        files.each { |file| upload_screenshot(set["id"], file) }
        verified = wait_for_set(set["id"], files.length)
        checksums = verified.map { |item| item.dig("attributes", "sourceFileChecksum").to_s }
        raise Error, "#{display_key}: completed with unexpected screenshot order" unless checksums == expected

        puts "      verified files=#{verified.length} state=COMPLETE order=match"
      else
        relation = actual.sort == expected.sort ? "same files, different order" : "different files"
        puts "      would replace #{existing.length} with #{files.length} screenshot(s) (#{relation})"
      end
    end

    def find_or_create_set(localization_id, display_type)
      sets = client.collection(
        "/v1/appCustomProductPageLocalizations/#{localization_id}/appScreenshotSets",
        "fields[appScreenshotSets]" => "screenshotDisplayType",
        "limit" => "200"
      )
      existing = sets.find { |item| item.dig("attributes", "screenshotDisplayType") == display_type }
      return existing if existing

      return { "id" => "dry-run-#{localization_id}-#{display_type}" } unless @options[:apply]

      created = client.post("/v1/appScreenshotSets", {
        "data" => {
          "type" => "appScreenshotSets",
          "attributes" => { "screenshotDisplayType" => display_type },
          "relationships" => {
            "appCustomProductPageLocalization" => {
              "data" => { "type" => "appCustomProductPageLocalizations", "id" => localization_id }
            }
          }
        }
      }).fetch("data")
      puts "    created #{display_type} set id=#{created["id"]}"
      created
    end

    def screenshots(set_id)
      return [] if set_id.start_with?("dry-run-")

      client.collection(
        "/v1/appScreenshotSets/#{set_id}/appScreenshots",
        "fields[appScreenshots]" => "fileName,sourceFileChecksum,assetDeliveryState,imageAsset",
        "limit" => "50"
      )
    end

    def upload_screenshot(set_id, file)
      reservation = client.post("/v1/appScreenshots", {
        "data" => {
          "type" => "appScreenshots",
          "attributes" => { "fileName" => file.basename.to_s, "fileSize" => file.size },
          "relationships" => {
            "appScreenshotSet" => { "data" => { "type" => "appScreenshotSets", "id" => set_id } }
          }
        }
      }).fetch("data")
      operations = Array(reservation.dig("attributes", "uploadOperations"))
      raise Error, "No upload operations returned for #{file}" if operations.empty?

      direct_client.upload_operations(operations, file)
      checksum = Digest::MD5.file(file).hexdigest
      committed = client.patch("/v1/appScreenshots/#{reservation["id"]}", {
        "data" => {
          "type" => "appScreenshots",
          "id" => reservation["id"],
          "attributes" => { "sourceFileChecksum" => checksum, "uploaded" => true }
        }
      }).fetch("data")
      puts "      uploaded #{file.basename} state=#{committed.dig("attributes", "assetDeliveryState", "state")}"
    end

    def complete?(items)
      items.all? do |item|
        !item.dig("attributes", "sourceFileChecksum").to_s.empty? &&
          item.dig("attributes", "assetDeliveryState", "state") == "COMPLETE"
      end
    end

    def wait_for_set(set_id, expected_count)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @options[:timeout_seconds]
      last_status = nil
      loop do
        items = screenshots(set_id)
        states = items.map { |item| item.dig("attributes", "assetDeliveryState", "state") || "unknown" }
        failed = items.find { |item| item.dig("attributes", "assetDeliveryState", "state") == "FAILED" }
        raise Error, "Screenshot processing failed for #{failed["id"]}" if failed

        status = "count=#{items.length}/#{expected_count} states=#{states.tally}"
        if status != last_status
          puts "      processing #{status}"
          last_status = status
        end
        return items if items.length == expected_count && complete?(items)
        raise Error, "Timed out waiting for screenshot set #{set_id}; last #{status}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep @options[:poll_seconds]
      end
    end
  end
end

begin
  ASCCustomProductPageScreenshots::Runner.new(ARGV).run
rescue ASCCustomProductPageScreenshots::Error, ASCScreenshotUpload::Error, ASCMetadata::Error => e
  warn "error: #{e.message}"
  exit 1
rescue OptionParser::InvalidOption => e
  warn "error: #{e.message}"
  exit 1
end
