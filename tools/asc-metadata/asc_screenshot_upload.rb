#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "net/http"
require "optparse"
require "pathname"
require "set"
require "uri"

require_relative "asc_metadata"

module ASCScreenshotUpload
  PLATFORM_CONFIG = {
    "IOS" => [
      ["APP_IPHONE_65", "ios"],
      ["APP_IPAD_PRO_3GEN_129", "ipad"],
      ["APP_WATCH_ULTRA", "watch"]
    ],
    "MAC_OS" => [["APP_DESKTOP", "mac"]],
    "TV_OS" => [["APP_APPLE_TV", "tvos"]],
    "VISION_OS" => [["APP_APPLE_VISION_PRO", "visionos"]]
  }.freeze

  DEFAULT_OPTIONS = {
    app_id: ASCMetadata::DEFAULT_APP_ID,
    version: ASCMetadata::DEFAULT_VERSION,
    source_locale_dir: "en",
    target_locale: ASCMetadata::DEFAULT_TARGET_LOCALE,
    root: "tools/appstore-screenshots/output/store",
    platforms: [],
    exclude_shots: [],
    apply: false
  }.freeze

  class Error < StandardError; end

  class DirectClient
    API_BASE = ASCMetadata::API_BASE

    def initialize(client)
      @client = client
    end

    def delete(path)
      uri = URI("#{API_BASE}#{path}")
      request = Net::HTTP::Delete.new(uri)
      request["Authorization"] = "Bearer #{@client.send(:jwt)}"
      request["Accept"] = "application/json"
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
      return if response.code == "204"

      raise_response_error(uri, response)
    end

    def upload_operations(operations, file_path)
      data = File.binread(file_path)
      operations.each_with_index do |operation, index|
        uri = URI(operation.fetch("url"))
        request = build_upload_request(operation, uri)
        offset = operation.fetch("offset")
        length = operation.fetch("length")
        request.body = data.byteslice(offset, length)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(request)
        end
        next if response.is_a?(Net::HTTPSuccess)

        raise Error, "Upload operation #{index + 1}/#{operations.length} failed: " \
                     "#{response.code} #{response.message} #{response.body.to_s[0, 300]}"
      end
    end

    private

    def build_upload_request(operation, uri)
      klass = case operation.fetch("method").upcase
              when "PUT" then Net::HTTP::Put
              when "POST" then Net::HTTP::Post
              else raise Error, "Unsupported upload method: #{operation.fetch("method")}"
              end
      request = klass.new(uri)
      Array(operation["requestHeaders"]).each do |header|
        request[header.fetch("name")] = header.fetch("value")
      end
      request
    end

    def raise_response_error(uri, response)
      body = response.body.to_s.empty? ? {} : JSON.parse(response.body)
      detail = body.dig("errors", 0, "detail") ||
               body.dig("errors", 0, "title") ||
               response.message
      raise Error, "#{response.code} #{response.message} for #{uri}: #{detail}"
    rescue JSON::ParserError
      raise Error, "#{response.code} #{response.message} for #{uri}: #{response.body}"
    end
  end

  class Runner
    def initialize(argv)
      @options = DEFAULT_OPTIONS.merge(platforms: [], exclude_shots: [])
      parse!(argv)
    end

    def run
      mode = @options[:apply] ? "APPLY" : "DRY-RUN"
      puts "#{mode}: upload screenshots #{@options[:source_locale_dir]} -> #{@options[:target_locale]} " \
           "for app #{@options[:app_id]}, version #{@options[:version]}"
      puts

      app_store_versions.each do |version|
        platform = version.dig("attributes", "platform")
        next unless platform_config.key?(platform)

        localization = target_localization(version)
        puts "VERSION #{platform} id=#{version["id"]} localization=#{localization["id"]}"
        platform_config.fetch(platform).each do |display_type, local_dir|
          upload_display_type(localization, display_type, local_dir)
        end
        puts
      end
    end

    private

    def parse!(argv)
      OptionParser.new do |opts|
        opts.banner = "Usage: ruby tools/asc-metadata/asc_screenshot_upload.rb [options]"
        opts.on("--app-id ID", "ASC app Apple ID") { |v| @options[:app_id] = v }
        opts.on("--version VERSION", "App Store version string") { |v| @options[:version] = v }
        opts.on("--source-locale-dir DIR", "Local screenshot locale directory, e.g. en") { |v| @options[:source_locale_dir] = v }
        opts.on("--target-locale LOCALE", "ASC locale, e.g. en-GB") { |v| @options[:target_locale] = v }
        opts.on("--root PATH", "Local screenshot output root") { |v| @options[:root] = v }
        opts.on("--platform PLATFORM", "Restrict platform; can be repeated") { |v| @options[:platforms] << v.upcase }
        opts.on("--exclude-shot ID", "Skip local screenshot id/stem; can be repeated") { |v| @options[:exclude_shots] << v }
        opts.on("--apply", "Write changes to App Store Connect") { @options[:apply] = true }
        opts.on("-h", "--help", "Show help") { abort opts.to_s }
      end.parse!(argv)
    end

    def client
      @client ||= ASCMetadata::Client.new(
        issuer_id: required_env("ASC_ISSUER_ID"),
        key_id: required_env("ASC_KEY_ID"),
        private_key_pem: private_key_pem
      )
    end

    def direct_client
      @direct_client ||= DirectClient.new(client)
    end

    def required_env(name)
      value = ENV[name].to_s.strip
      return value unless value.empty?

      raise Error, "Missing #{name}. Provide it as an environment variable."
    end

    def private_key_pem
      inline = ENV["ASC_PRIVATE_KEY"].to_s
      return inline.gsub("\\n", "\n") unless inline.strip.empty?

      path = ENV["ASC_PRIVATE_KEY_PATH"].to_s.strip
      raise Error, "Missing ASC_PRIVATE_KEY_PATH or ASC_PRIVATE_KEY." if path.empty?

      File.read(path)
    end

    def app_store_versions
      versions = client.collection(
        "/v1/apps/#{@options[:app_id]}/appStoreVersions",
        "filter[versionString]" => @options[:version],
        "fields[appStoreVersions]" => "platform,versionString,appStoreState",
        "limit" => "200"
      )
      platforms = @options[:platforms]
      versions = versions.select { |version| platforms.include?(version.dig("attributes", "platform").to_s.upcase) } unless platforms.empty?
      versions.sort_by { |version| version.dig("attributes", "platform").to_s }
    end

    def platform_config
      platforms = @options[:platforms]
      return PLATFORM_CONFIG if platforms.empty?

      PLATFORM_CONFIG.select { |platform, _| platforms.include?(platform) }
    end

    def target_localization(version)
      localizations = client.collection(
        "/v1/appStoreVersions/#{version["id"]}/appStoreVersionLocalizations",
        "fields[appStoreVersionLocalizations]" => "locale",
        "limit" => "200"
      )
      localization = localizations.find { |loc| loc.dig("attributes", "locale") == @options[:target_locale] }
      return localization if localization

      raise Error, "Missing #{@options[:target_locale]} localization for #{version.dig("attributes", "platform")}"
    end

    def upload_display_type(localization, display_type, local_dir)
      files = screenshot_files(local_dir)
      raise Error, "No local screenshots found for #{local_dir}/#{@options[:source_locale_dir]}" if files.empty?

      set = find_or_create_set(localization, display_type)
      existing = screenshots(set["id"])
      puts "  #{display_type} from #{local_dir}/#{@options[:source_locale_dir]} files=#{files.length} existing=#{existing.length}"

      match = checksum_match(existing, files)
      if match
        puts "    SKIP already matches local files#{match == :set ? " (checksum set)" : ""}"
        return
      end

      if existing.any?
        if @options[:apply]
          existing.each do |screenshot|
            direct_client.delete("/v1/appScreenshots/#{screenshot["id"]}")
            puts "    deleted #{screenshot["id"]}"
          end
        else
          puts "    would delete #{existing.length} existing screenshots"
        end
      end

      files.each do |file|
        if @options[:apply]
          upload_screenshot(set["id"], file)
        else
          puts "    would upload #{file.basename}"
        end
      end
    end

    def screenshot_files(local_dir)
      excluded = @options[:exclude_shots].to_set
      Pathname(@options[:root]).join(local_dir, @options[:source_locale_dir]).glob("*.png").sort.reject do |file|
        excluded.include?(file.basename(".png").to_s)
      end
    end

    def find_or_create_set(localization, display_type)
      sets = client.collection(
        "/v1/appStoreVersionLocalizations/#{localization["id"]}/appScreenshotSets",
        "fields[appScreenshotSets]" => "screenshotDisplayType",
        "limit" => "200"
      )
      existing = sets.find { |set| set.dig("attributes", "screenshotDisplayType") == display_type }
      return existing if existing

      if @options[:apply]
        created = client.post("/v1/appScreenshotSets", screenshot_set_body(localization["id"], display_type))["data"]
        puts "  created set #{display_type} id=#{created["id"]}"
        return created
      end

      puts "  would create set #{display_type}"
      { "id" => "dry-run-#{display_type}", "attributes" => { "screenshotDisplayType" => display_type } }
    end

    def screenshot_set_body(localization_id, display_type)
      {
        "data" => {
          "type" => "appScreenshotSets",
          "attributes" => { "screenshotDisplayType" => display_type },
          "relationships" => {
            "appStoreVersionLocalization" => {
              "data" => { "type" => "appStoreVersionLocalizations", "id" => localization_id }
            }
          }
        }
      }
    end

    def screenshots(set_id)
      return [] if set_id.start_with?("dry-run-")

      client.collection(
        "/v1/appScreenshotSets/#{set_id}/appScreenshots",
        "fields[appScreenshots]" => "fileName,sourceFileChecksum,assetDeliveryState,imageAsset",
        "limit" => "200"
      )
    end

    def checksum_match(existing, files)
      existing_checksums = existing.map { |screenshot| screenshot.dig("attributes", "sourceFileChecksum") }
      local_checksums = files.map { |file| Digest::MD5.file(file).hexdigest }
      return :ordered if existing_checksums == local_checksums
      return :set if existing_checksums.sort == local_checksums.sort

      nil
    end

    def upload_screenshot(set_id, file)
      reservation = client.post("/v1/appScreenshots", screenshot_body(set_id, file))["data"]
      operations = Array(reservation.dig("attributes", "uploadOperations"))
      raise Error, "No upload operations returned for #{file}" if operations.empty?

      direct_client.upload_operations(operations, file)
      checksum = Digest::MD5.file(file).hexdigest
      committed = client.patch("/v1/appScreenshots/#{reservation["id"]}", {
        "data" => {
          "type" => "appScreenshots",
          "id" => reservation["id"],
          "attributes" => {
            "sourceFileChecksum" => checksum,
            "uploaded" => true
          }
        }
      })["data"]
      state = committed.dig("attributes", "assetDeliveryState", "state")
      puts "    uploaded #{file.basename} id=#{committed["id"]} checksum=#{checksum} state=#{state}"
    end

    def screenshot_body(set_id, file)
      {
        "data" => {
          "type" => "appScreenshots",
          "attributes" => {
            "fileName" => file.basename.to_s,
            "fileSize" => file.size
          },
          "relationships" => {
            "appScreenshotSet" => {
              "data" => { "type" => "appScreenshotSets", "id" => set_id }
            }
          }
        }
      }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  ASCScreenshotUpload::Runner.new(ARGV).run
end
