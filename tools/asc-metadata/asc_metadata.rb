#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "digest"
require "json"
require "net/http"
require "openssl"
require "optparse"
require "pathname"
require "time"
require "uri"

module ASCMetadata
  API_BASE = "https://api.appstoreconnect.apple.com"
  DEFAULT_APP_ID = "6761892533"
  DEFAULT_VERSION = "1.5.0"
  DEFAULT_SOURCE_LOCALE = "en-US"
  DEFAULT_TARGET_LOCALE = "en-GB"
  DEFAULT_PLANNED_LOCALES = %w[zh-Hans zh-Hant en-US ja].freeze
  DEFAULT_FUTURE_LOCALES = %w[ko].freeze
  DEFAULT_SCREENSHOT_ROOT = "tools/appstore-screenshots/output/store"

  SCREENSHOT_LOCALE_DIRS = {
    "zh-Hans" => "zh-Hans",
    "zh-Hant" => "zh-Hant",
    "en-US" => "en",
    "en-GB" => "en",
    "ja" => "ja",
    "ko" => "ko"
  }.freeze

  SCREENSHOT_DISPLAY_TYPES = {
    "IOS" => [
      ["APP_IPHONE_65", "ios"],
      ["APP_IPAD_PRO_3GEN_129", "ipad"],
      ["APP_WATCH_ULTRA", "watch"]
    ],
    "MAC_OS" => [["APP_DESKTOP", "mac"]],
    "TV_OS" => [["APP_APPLE_TV", "tvos"]],
    "VISION_OS" => [["APP_APPLE_VISION_PRO", "visionos"]]
  }.freeze

  APP_INFO_FIELDS = %w[
    name
    subtitle
    privacyPolicyUrl
    privacyPolicyText
  ].freeze

  VERSION_FIELDS = %w[
    description
    keywords
    marketingUrl
    promotionalText
    supportUrl
    whatsNew
  ].freeze

  class Error < StandardError; end

  class Client
    def initialize(issuer_id:, key_id:, private_key_pem:)
      @issuer_id = issuer_id
      @key_id = key_id
      @private_key = OpenSSL::PKey::EC.new(private_key_pem)
      @token = nil
      @token_expires_at = Time.at(0)
    end

    def get(path, query = {})
      request(:get, path, query: query)
    end

    def post(path, body)
      request(:post, path, body: body)
    end

    def patch(path, body)
      request(:patch, path, body: body)
    end

    def collection(path, query = {})
      items = []
      response = get(path, query)
      loop do
        items.concat(Array(response["data"]))
        next_link = response.dig("links", "next")
        break unless next_link && !next_link.empty?

        response = request(:get, next_link)
      end
      items
    end

    private

    def request(method, path_or_url, query: {}, body: nil)
      uri = build_uri(path_or_url, query)
      request = build_request(method, uri, body)
      response = perform(uri, request)
      parse_response(uri, response)
    end

    def build_uri(path_or_url, query)
      uri = if path_or_url.start_with?("http")
              URI(path_or_url)
            else
              URI("#{API_BASE}#{path_or_url}")
            end

      unless query.empty?
        encoded = URI.encode_www_form(query)
        uri.query = [uri.query, encoded].compact.reject(&:empty?).join("&")
      end
      uri
    end

    def build_request(method, uri, body)
      klass = case method
              when :get then Net::HTTP::Get
              when :post then Net::HTTP::Post
              when :patch then Net::HTTP::Patch
              else raise Error, "Unsupported HTTP method: #{method}"
              end

      request = klass.new(uri)
      request["Authorization"] = "Bearer #{jwt}"
      request["Accept"] = "application/json"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body) if body
      request
    end

    def perform(uri, request)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end
    end

    def parse_response(uri, response)
      body = response.body.to_s.empty? ? {} : JSON.parse(response.body)
      return body if response.is_a?(Net::HTTPSuccess)

      message = body.dig("errors", 0, "detail") ||
                body.dig("errors", 0, "title") ||
                response.message
      raise Error, "#{response.code} #{response.message} for #{uri}: #{message}"
    rescue JSON::ParserError
      raise Error, "#{response.code} #{response.message} for #{uri}: #{response.body}"
    end

    def jwt
      return @token if Time.now < @token_expires_at

      now = Time.now.to_i
      header = {
        "alg" => "ES256",
        "kid" => @key_id,
        "typ" => "JWT"
      }
      payload = {
        "iss" => @issuer_id,
        "iat" => now,
        "exp" => now + 20 * 60,
        "aud" => "appstoreconnect-v1"
      }

      signing_input = [base64url_json(header), base64url_json(payload)].join(".")
      signature = @private_key.dsa_sign_asn1(OpenSSL::Digest::SHA256.digest(signing_input))
      @token = [signing_input, base64url(ecdsa_der_to_raw(signature))].join(".")
      @token_expires_at = Time.at(now + 19 * 60)
      @token
    end

    def base64url_json(value)
      base64url(JSON.generate(value))
    end

    def base64url(value)
      Base64.urlsafe_encode64(value).delete("=")
    end

    def ecdsa_der_to_raw(signature)
      sequence = OpenSSL::ASN1.decode(signature)
      unless sequence.value.size == 2
        raise Error, "Unexpected ECDSA signature shape"
      end

      r, s = sequence.value.map(&:value)
      int_to_fixed_bytes(r, 32) + int_to_fixed_bytes(s, 32)
    end

    def int_to_fixed_bytes(value, width)
      hex = value.to_s(16)
      hex = "0#{hex}" if hex.length.odd?
      bytes = [hex].pack("H*")
      if bytes.bytesize > width
        bytes[-width, width]
      else
        bytes.rjust(width, "\x00")
      end
    end
  end

  class Runner
    def initialize(argv)
      if argv.empty? || argv.include?("--help") || argv.include?("-h")
        puts usage
        exit 0
      end

      @command = argv.shift
      @options = {
        app_id: ENV["ASC_APP_ID"] || DEFAULT_APP_ID,
        version: ENV["ASC_VERSION"] || DEFAULT_VERSION,
        source_locale: ENV["ASC_SOURCE_LOCALE"] || DEFAULT_SOURCE_LOCALE,
        target_locale: ENV["ASC_TARGET_LOCALE"] || DEFAULT_TARGET_LOCALE,
        screenshot_root: ENV["ASC_SCREENSHOT_ROOT"] || DEFAULT_SCREENSHOT_ROOT,
        planned_locales: [],
        future_locales: [],
        exclude_shots: [],
        apply: false,
        platforms: []
      }
      parse_options(argv)
    end

    def run
      case @command
      when "audit"
        audit
      when "copy-locale"
        copy_locale
      else
        abort usage
      end
    end

    private

    def parse_options(argv)
      OptionParser.new do |opts|
        opts.banner = "Usage: #{$PROGRAM_NAME} audit|copy-locale [options]"
        opts.on("--app-id APPLE_ID", "App Apple ID, default #{DEFAULT_APP_ID}") { |v| @options[:app_id] = v }
        opts.on("--version VERSION", "Version string, default #{DEFAULT_VERSION}") { |v| @options[:version] = v }
        opts.on("--source-locale LOCALE", "Source locale, default #{DEFAULT_SOURCE_LOCALE}") { |v| @options[:source_locale] = v }
        opts.on("--target-locale LOCALE", "Target locale, default #{DEFAULT_TARGET_LOCALE}") { |v| @options[:target_locale] = v }
        opts.on("--planned-locale LOCALE", "Expected ASC locale; can be repeated") { |v| @options[:planned_locales] << v }
        opts.on("--future-locale LOCALE", "Known future locale; can be repeated") { |v| @options[:future_locales] << v }
        opts.on("--screenshot-root PATH", "Local store screenshot root, default #{DEFAULT_SCREENSHOT_ROOT}") { |v| @options[:screenshot_root] = v }
        opts.on("--exclude-shot ID", "Ignore local screenshot id/stem during asset audit; can be repeated") { |v| @options[:exclude_shots] << v }
        opts.on("--platform PLATFORM", "Restrict app store version platform; can be repeated") { |v| @options[:platforms] << v.upcase }
        opts.on("--apply", "Write changes to App Store Connect. Omit for dry-run.") { @options[:apply] = true }
        opts.on("-h", "--help", "Show help") { abort opts.to_s }
      end.parse!(argv)
    end

    def usage
      <<~USAGE
        Usage:
          # Audit current ASC localizations for AutoLedger 1.5.0
          ASC_ISSUER_ID=... ASC_KEY_ID=... ASC_PRIVATE_KEY_PATH=/secure/AuthKey.p8 \\
            ruby tools/asc-metadata/asc_metadata.rb audit

          # Preview copying English (U.S.) metadata to English (U.K.)
          ASC_ISSUER_ID=... ASC_KEY_ID=... ASC_PRIVATE_KEY_PATH=/secure/AuthKey.p8 \\
            ruby tools/asc-metadata/asc_metadata.rb copy-locale

          # Apply the copy
          ASC_ISSUER_ID=... ASC_KEY_ID=... ASC_PRIVATE_KEY_PATH=/secure/AuthKey.p8 \\
            ruby tools/asc-metadata/asc_metadata.rb copy-locale --apply
      USAGE
    end

    def client
      @client ||= Client.new(
        issuer_id: required_env("ASC_ISSUER_ID"),
        key_id: required_env("ASC_KEY_ID"),
        private_key_pem: private_key_pem
      )
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

    def audit
      puts "ASC audit for app #{@options[:app_id]}, version #{@options[:version]}"
      puts "Source locale: #{@options[:source_locale]}, target locale: #{@options[:target_locale]}"
      puts "Planned locales: #{planned_locales.join(", ")}"
      puts "Future locales: #{future_locales.join(", ")}"
      puts "Screenshot root: #{@options[:screenshot_root]}"
      puts

      app_info = app_info!
      localizations = app_info_localizations(app_info["id"])
      print_app_info_localizations(localizations)
      print_app_info_matrix(localizations)

      versions = app_store_versions
      print_version_localizations(versions)
      print_version_asset_matrix(versions)
      print_local_screenshot_matrix
    end

    def copy_locale
      source = @options[:source_locale]
      target = @options[:target_locale]
      mode = @options[:apply] ? "APPLY" : "DRY-RUN"
      puts "#{mode}: copy #{source} -> #{target} for app #{@options[:app_id]}, version #{@options[:version]}"
      puts

      app_info = app_info!
      copy_app_info_locale(app_info["id"], source, target)
      app_store_versions.each { |version| copy_version_locale(version, source, target) }
    end

    def app_info!
      infos = client.collection("/v1/apps/#{@options[:app_id]}/appInfos", "limit" => "20")
      raise Error, "No appInfo found for app #{@options[:app_id]}" if infos.empty?

      infos.first
    end

    def app_info_localizations(app_info_id)
      client.collection(
        "/v1/appInfos/#{app_info_id}/appInfoLocalizations",
        "fields[appInfoLocalizations]" => (APP_INFO_FIELDS + ["locale"]).join(","),
        "limit" => "200"
      )
    end

    def app_store_versions
      versions = client.collection(
        "/v1/apps/#{@options[:app_id]}/appStoreVersions",
        "filter[versionString]" => @options[:version],
        "limit" => "200"
      )
      platforms = @options[:platforms]
      return versions if platforms.empty?

      versions.select { |version| platforms.include?(version.dig("attributes", "platform").to_s.upcase) }
    end

    def version_localizations(version_id)
      client.collection(
        "/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations",
        "fields[appStoreVersionLocalizations]" => (VERSION_FIELDS + ["locale"]).join(","),
        "limit" => "200"
      )
    end

    def print_app_info_localizations(localizations)
      puts "App Info Localizations"
      localizations.sort_by { |loc| loc.dig("attributes", "locale").to_s }.each do |loc|
        attrs = loc["attributes"] || {}
        puts "  - #{attrs["locale"]} id=#{loc["id"]} " \
             "name=#{summary(attrs["name"])} " \
             "subtitle=#{summary(attrs["subtitle"])} " \
             "privacyPolicyUrl=#{presence(attrs["privacyPolicyUrl"])} " \
             "privacyPolicyText=#{length_summary(attrs["privacyPolicyText"])}"
      end
      puts
    end

    def print_app_info_matrix(localizations)
      puts "App Info Locale Matrix"
      present = localizations.map { |loc| loc.dig("attributes", "locale") }.compact.sort
      puts "  present: #{present.join(", ")}"
      print_locale_gaps("app info", present)
      localizations.sort_by { |loc| loc.dig("attributes", "locale").to_s }.each do |loc|
        attrs = loc["attributes"] || {}
        locale = attrs["locale"].to_s
        missing = missing_fields(attrs, APP_INFO_FIELDS)
        fields = missing.empty? ? "ok" : "missing:#{missing.join(",")}"
        puts "  - #{locale} #{locale_state(locale)} fields=#{fields}"
      end
      puts
    end

    def print_version_localizations(versions)
      puts "App Store Versions"
      versions.each do |version|
        attrs = version["attributes"] || {}
        puts "  - #{attrs["platform"]} #{attrs["versionString"]} " \
             "state=#{attrs["appStoreState"]} id=#{version["id"]}"

        version_localizations(version["id"]).sort_by { |loc| loc.dig("attributes", "locale").to_s }.each do |loc|
          loc_attrs = loc["attributes"] || {}
          puts "      #{loc_attrs["locale"]} id=#{loc["id"]} " \
               "description=#{length_summary(loc_attrs["description"])} " \
               "keywords=#{length_summary(loc_attrs["keywords"])} " \
               "promotionalText=#{length_summary(loc_attrs["promotionalText"])} " \
               "whatsNew=#{length_summary(loc_attrs["whatsNew"])}"
        end
      end
      puts
    end

    def print_version_asset_matrix(versions)
      puts "Version Locale / Asset Matrix"
      versions.each do |version|
        attrs = version["attributes"] || {}
        platform = attrs["platform"].to_s
        localizations = version_localizations(version["id"])
        present = localizations.map { |loc| loc.dig("attributes", "locale") }.compact.sort
        puts "  - #{platform} #{attrs["versionString"]} state=#{attrs["appStoreState"]} id=#{version["id"]}"
        puts "      present: #{present.join(", ")}"
        print_locale_gaps("#{platform} version", present, indent: "      ")
        localizations.sort_by { |loc| loc.dig("attributes", "locale").to_s }.each do |loc|
          print_version_asset_row(platform, loc)
        end
      end
      puts
    end

    def print_version_asset_row(platform, localization)
      attrs = localization["attributes"] || {}
      locale = attrs["locale"].to_s
      missing = missing_fields(attrs, VERSION_FIELDS)
      screenshots = screenshot_asset_summary(platform, localization["id"], locale)
      previews = app_preview_summary(localization["id"])
      puts "      #{locale} #{locale_state(locale)} " \
           "fields=#{missing.empty? ? "ok" : "missing:#{missing.join(",")}"} " \
           "screenshots=#{screenshots} previews=#{previews}"
    end

    def print_local_screenshot_matrix
      puts "Local Screenshot Matrix"
      puts "  root=#{@options[:screenshot_root]}"
      locales = (planned_locales + future_locales + [@options[:target_locale]]).uniq
      locales.each do |locale|
        local_locale = local_screenshot_locale(locale)
        counts = SCREENSHOT_DISPLAY_TYPES.values.flatten(1).map do |display_type, local_dir|
          count = local_screenshot_files(local_dir, locale).length
          "#{local_dir}/#{display_type}=#{count}"
        end
        puts "  - #{locale} local=#{local_locale} #{counts.join(" ")}"
      end
      puts
    end

    def copy_app_info_locale(app_info_id, source_locale, target_locale)
      localizations = app_info_localizations(app_info_id)
      source = find_locale!(localizations, source_locale, "app info")
      target = find_locale(localizations, target_locale)
      attrs = copied_attributes(source, APP_INFO_FIELDS, include_locale: target.nil?, target_locale: target_locale)

      warn_missing(source, APP_INFO_FIELDS, "app info #{source_locale}")
      if target
        attrs = changed_attributes(source, target, APP_INFO_FIELDS)
        patch_resource("appInfoLocalizations", target["id"], attrs, "app info #{target_locale}")
      else
        create_resource(
          "appInfoLocalizations",
          attrs,
          { "appInfo" => { "data" => { "type" => "appInfos", "id" => app_info_id } } },
          "app info #{target_locale}"
        )
      end
    end

    def copy_version_locale(version, source_locale, target_locale)
      version_attrs = version["attributes"] || {}
      label = "#{version_attrs["platform"]} #{version_attrs["versionString"]}"
      localizations = version_localizations(version["id"])
      source = find_locale!(localizations, source_locale, "#{label} version")
      target = find_locale(localizations, target_locale)
      attrs = copied_attributes(source, VERSION_FIELDS, include_locale: target.nil?, target_locale: target_locale)

      warn_missing(source, VERSION_FIELDS, "#{label} #{source_locale}")
      if target
        attrs = changed_attributes(source, target, VERSION_FIELDS)
        patch_resource("appStoreVersionLocalizations", target["id"], attrs, "#{label} #{target_locale}")
      else
        create_resource(
          "appStoreVersionLocalizations",
          attrs,
          { "appStoreVersion" => { "data" => { "type" => "appStoreVersions", "id" => version["id"] } } },
          "#{label} #{target_locale}"
        )
      end
    end

    def planned_locales
      locales = @options[:planned_locales]
      locales.empty? ? DEFAULT_PLANNED_LOCALES : locales.uniq
    end

    def future_locales
      locales = @options[:future_locales]
      locales.empty? ? DEFAULT_FUTURE_LOCALES : locales.uniq
    end

    def locale_state(locale)
      if planned_locales.include?(locale)
        "planned"
      elsif future_locales.include?(locale)
        "future"
      else
        "stale"
      end
    end

    def print_locale_gaps(label, present, indent: "  ")
      missing = planned_locales - present
      stale = present - planned_locales - future_locales
      puts "#{indent}missing planned #{label} locales: #{missing.join(", ")}" unless missing.empty?
      puts "#{indent}stale #{label} locales: #{stale.join(", ")}" unless stale.empty?
    end

    def missing_fields(attrs, fields)
      fields.select { |field| attrs[field].nil? || attrs[field].to_s.empty? }
    end

    def screenshot_asset_summary(platform, localization_id, locale)
      expected = SCREENSHOT_DISPLAY_TYPES[platform]
      return "n/a" unless expected

      sets = app_screenshot_sets(localization_id)
      sets_by_type = sets.each_with_object({}) do |set, result|
        result[set.dig("attributes", "screenshotDisplayType").to_s] = set
      end
      summaries = expected.map do |display_type, local_dir|
        set = sets_by_type[display_type]
        local_files = local_screenshot_files(local_dir, locale)
        if set
          screenshots = app_screenshots(set["id"])
          state = checksum_state(screenshots, local_files)
          "#{display_type}:#{screenshots.length}/#{local_files.length}:#{state}"
        else
          "#{display_type}:missing/#{local_files.length}"
        end
      end
      extra = (sets_by_type.keys - expected.map(&:first)).sort
      summaries << "extra=#{extra.join("|")}" unless extra.empty?
      summaries.join(",")
    end

    def app_screenshot_sets(localization_id)
      client.collection(
        "/v1/appStoreVersionLocalizations/#{localization_id}/appScreenshotSets",
        "fields[appScreenshotSets]" => "screenshotDisplayType",
        "limit" => "200"
      )
    rescue Error => e
      warn "  warning: could not read screenshot sets for #{localization_id}: #{e.message}"
      []
    end

    def app_screenshots(set_id)
      client.collection(
        "/v1/appScreenshotSets/#{set_id}/appScreenshots",
        "fields[appScreenshots]" => "fileName,sourceFileChecksum,assetDeliveryState,imageAsset",
        "limit" => "200"
      )
    rescue Error => e
      warn "  warning: could not read screenshots for #{set_id}: #{e.message}"
      []
    end

    def app_preview_summary(localization_id)
      sets = app_preview_sets(localization_id)
      return "none" if sets.empty?

      sets.map do |set|
        type = set.dig("attributes", "previewType") ||
               set.dig("attributes", "appPreviewType") ||
               set.dig("attributes", "previewDisplayType") ||
               "unknown"
        previews = app_previews(set["id"])
        "#{type}:#{previews.length}"
      end.join(",")
    end

    def app_preview_sets(localization_id)
      client.collection(
        "/v1/appStoreVersionLocalizations/#{localization_id}/appPreviewSets",
        "limit" => "200"
      )
    rescue Error => e
      warn "  warning: could not read app preview sets for #{localization_id}: #{e.message}"
      []
    end

    def app_previews(set_id)
      client.collection(
        "/v1/appPreviewSets/#{set_id}/appPreviews",
        "limit" => "200"
      )
    rescue Error => e
      warn "  warning: could not read app previews for #{set_id}: #{e.message}"
      []
    end

    def checksum_state(screenshots, local_files)
      return "remote-missing" if screenshots.empty?
      return "local-missing" if local_files.empty?

      remote = screenshots.map { |screenshot| screenshot.dig("attributes", "sourceFileChecksum") }.compact
      local = local_files.map { |file| Digest::MD5.file(file).hexdigest }
      return "match" if remote == local || remote.sort == local.sort

      "mismatch"
    end

    def local_screenshot_files(local_dir, locale)
      excluded = @options[:exclude_shots]
      Pathname(@options[:screenshot_root])
        .join(local_dir, local_screenshot_locale(locale))
        .glob("*.png")
        .sort
        .reject { |file| excluded.include?(file.basename(".png").to_s) }
    end

    def local_screenshot_locale(locale)
      SCREENSHOT_LOCALE_DIRS.fetch(locale, locale)
    end

    def find_locale(localizations, locale)
      localizations.find { |loc| loc.dig("attributes", "locale") == locale }
    end

    def find_locale!(localizations, locale, label)
      found = find_locale(localizations, locale)
      return found if found

      available = localizations.map { |loc| loc.dig("attributes", "locale") }.compact.sort.join(", ")
      raise Error, "Missing #{locale} #{label} localization. Available: #{available}"
    end

    def copied_attributes(source, fields, include_locale:, target_locale:)
      source_attrs = source["attributes"] || {}
      attrs = {}
      attrs["locale"] = target_locale if include_locale
      fields.each do |field|
        value = source_attrs[field]
        attrs[field] = value unless value.nil?
      end
      attrs
    end

    def changed_attributes(source, target, fields)
      source_attrs = source["attributes"] || {}
      target_attrs = target["attributes"] || {}
      fields.each_with_object({}) do |field, attrs|
        value = source_attrs[field]
        next if value.nil?
        next if target_attrs[field] == value

        attrs[field] = value
      end
    end

    def warn_missing(source, fields, label)
      source_attrs = source["attributes"] || {}
      missing = fields.select { |field| source_attrs[field].nil? || source_attrs[field].to_s.empty? }
      return if missing.empty?

      warn "  warning: #{label} has empty fields: #{missing.join(", ")}"
    end

    def patch_resource(type, id, attrs, label)
      if attrs.empty?
        puts "  #{label} already matches source; skipped"
        return
      end

      body = { "data" => { "type" => type, "id" => id, "attributes" => attrs } }
      if @options[:apply]
        client.patch("/v1/#{type}/#{id}", body)
        puts "  updated #{label} (#{id})"
      else
        puts "  would update #{label} (#{id}): #{attrs_summary(attrs)}"
      end
    end

    def create_resource(type, attrs, relationships, label)
      body = { "data" => { "type" => type, "attributes" => attrs, "relationships" => relationships } }
      if @options[:apply]
        response = client.post("/v1/#{type}", body)
        puts "  created #{label} (#{response.dig("data", "id")})"
      else
        puts "  would create #{label}: #{attrs_summary(attrs)}"
      end
    end

    def attrs_summary(attrs)
      attrs.map do |key, value|
        "#{key}=#{length_summary(value)}"
      end.join(", ")
    end

    def presence(value)
      value.to_s.empty? ? "missing" : "present"
    end

    def length_summary(value)
      return "missing" if value.nil? || value.to_s.empty?

      "#{value.to_s.length} chars"
    end

    def summary(value)
      return "missing" if value.nil? || value.to_s.empty?

      text = value.to_s.gsub(/\s+/, " ")
      text.length > 36 ? "#{text[0, 33]}..." : text
    end
  end
end

begin
ASCMetadata::Runner.new(ARGV).run if $PROGRAM_NAME == __FILE__
rescue ASCMetadata::Error => e
  warn "error: #{e.message}"
  exit 1
rescue OptionParser::InvalidOption => e
  warn "error: #{e.message}"
  exit 1
end
