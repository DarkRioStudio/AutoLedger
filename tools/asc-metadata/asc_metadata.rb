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
require "yaml"

module ASCMetadata
  API_BASE = "https://api.appstoreconnect.apple.com"
  DEFAULT_APP_ID = "6761892533"
  DEFAULT_VERSION = "1.6.0"
  DEFAULT_SOURCE_LOCALE = "en-US"
  DEFAULT_TARGET_LOCALE = "en-GB"
  DEFAULT_PLANNED_LOCALES = %w[zh-Hans zh-Hant en-US ja ko].freeze
  DEFAULT_FUTURE_LOCALES = [].freeze
  DEFAULT_SCREENSHOT_ROOT = "tools/appstore-screenshots/output/store"
  DEFAULT_METADATA_CONFIG = "tools/asc-metadata/metadata.yml"

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

  SUBSCRIPTION_GROUP_LOCALIZATION_FIELDS = %w[
    name
  ].freeze

  SUBSCRIPTION_LOCALIZATION_FIELDS = %w[
    name
    description
  ].freeze

  SUBSCRIPTION_DESCRIPTION_LIMIT = 55

  class Error < StandardError; end

  class Client
    TRANSIENT_HTTP_CODES = %w[429 500 502 503 504].freeze
    TRANSIENT_ERRORS = [
      EOFError,
      IOError,
      Net::OpenTimeout,
      Net::ReadTimeout,
      OpenSSL::SSL::SSLError,
      SocketError,
      Errno::ECONNRESET,
      Errno::ECONNREFUSED,
      Errno::ETIMEDOUT
    ].freeze
    MAX_ATTEMPTS = 5

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
      attempt = 0
      loop do
        attempt += 1
        begin
          response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
            http.open_timeout = 30
            http.read_timeout = 120
            http.write_timeout = 120
            http.request(request)
          end
          if TRANSIENT_HTTP_CODES.include?(response.code) && attempt < MAX_ATTEMPTS
            delay = retry_delay(response, attempt)
            warn "ASC transient HTTP #{response.code}; retry #{attempt}/#{MAX_ATTEMPTS} in #{delay}s"
            sleep delay
            next
          end
          return response
        rescue *TRANSIENT_ERRORS => e
          raise if attempt >= MAX_ATTEMPTS

          delay = [2**(attempt - 1), 8].min
          warn "ASC transient #{e.class}; retry #{attempt}/#{MAX_ATTEMPTS} in #{delay}s"
          sleep delay
        end
      end
    end

    def retry_delay(response, attempt)
      retry_after = response["Retry-After"].to_i
      return retry_after if retry_after.positive?

      [2**(attempt - 1), 8].min
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
        source_version: nil,
        output_path: nil,
        skip_app_info: false,
        skip_review_notes: false,
        skip_subscriptions: false,
        shared_create_only: false,
        locales: [],
        exclude_shots: [],
        config_path: DEFAULT_METADATA_CONFIG,
        apply: false,
        platforms: []
      }
      parse_options(argv)
    end

    def run
      case @command
      when "audit"
        audit
      when "export-config"
        export_config
      when "create-version"
        create_version
      when "copy-locale"
        copy_locale
      when "push-config"
        push_config
      else
        abort usage
      end
    end

    private

    def parse_options(argv)
      OptionParser.new do |opts|
        opts.banner = "Usage: #{$PROGRAM_NAME} audit|export-config|create-version|copy-locale|push-config [options]"
        opts.on("--app-id APPLE_ID", "App Apple ID, default #{DEFAULT_APP_ID}") { |v| @options[:app_id] = v }
        opts.on("--version VERSION", "Version string, default #{DEFAULT_VERSION}") { |v| @options[:version] = v }
        opts.on("--source-version VERSION", "Source version used to infer platforms for create-version") { |v| @options[:source_version] = v }
        opts.on("--output PATH", "Write export-config YAML to a reviewed archive path") { |v| @options[:output_path] = v }
        opts.on("--skip-app-info", "Skip app-wide name, subtitle, and privacy localization writes") { @options[:skip_app_info] = true }
        opts.on("--skip-review-notes", "Skip App Review Notes writes") { @options[:skip_review_notes] = true }
        opts.on("--skip-subscriptions", "Skip subscription metadata writes") { @options[:skip_subscriptions] = true }
        opts.on("--shared-create-only", "Create missing App Info/subscription locales without changing active existing locales") { @options[:shared_create_only] = true }
        opts.on("--locale LOCALE", "Restrict config writes to one locale; can be repeated") { |v| @options[:locales] << v }
        opts.on("--source-locale LOCALE", "Source locale, default #{DEFAULT_SOURCE_LOCALE}") { |v| @options[:source_locale] = v }
        opts.on("--target-locale LOCALE", "Target locale, default #{DEFAULT_TARGET_LOCALE}") { |v| @options[:target_locale] = v }
        opts.on("--config PATH", "Metadata YAML config, default #{DEFAULT_METADATA_CONFIG}") { |v| @options[:config_path] = v }
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

          # Preview pushing metadata.yml into ASC
          ASC_ISSUER_ID=... ASC_KEY_ID=... ASC_PRIVATE_KEY_PATH=/secure/AuthKey.p8 \\
            ruby tools/asc-metadata/asc_metadata.rb push-config --config tools/asc-metadata/metadata.yml
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
      print_review_details(versions)
      print_local_screenshot_matrix
      print_subscription_matrix
    end

    def export_config
      app_info = app_info!
      versions = app_store_versions
      raise Error, "No App Store versions found for #{@options[:version]}" if versions.empty?

      snapshot = {
        "app_id" => @options[:app_id],
        "version" => @options[:version],
        "exported_at" => Time.now.utc.iso8601,
        "app_info" => localization_snapshot(app_info_localizations(app_info["id"]), APP_INFO_FIELDS),
        "app_store_versions" => versions.sort_by { |item| item.dig("attributes", "platform").to_s }.map do |version|
          attrs = version["attributes"] || {}
          {
            "id" => version["id"],
            "platform" => attrs["platform"],
            "state" => attrs["appStoreState"],
            "version_string" => attrs["versionString"],
            "localizations" => localization_snapshot(version_localizations(version["id"]), VERSION_FIELDS),
            "review_detail" => review_detail_snapshot(version["id"])
          }
        end,
        "subscription_groups" => subscription_snapshot
      }
      yaml = YAML.dump(snapshot)
      output_path = @options[:output_path].to_s.strip
      if output_path.empty?
        puts yaml
      else
        Pathname(output_path).write(yaml)
        puts "Exported ASC #{@options[:version]} metadata to #{output_path}"
      end
    end

    def create_version
      source_version = @options[:source_version].to_s.strip
      platforms = @options[:platforms]
      if platforms.empty?
        raise Error, "Provide --platform or --source-version to select platforms." if source_version.empty?

        platforms = app_store_versions_for(source_version).map { |item| item.dig("attributes", "platform").to_s }.reject(&:empty?).uniq.sort
      end
      raise Error, "No source platforms found for #{source_version}" if platforms.empty?

      existing = app_store_versions_for(@options[:version])
      mode = @options[:apply] ? "APPLY" : "DRY-RUN"
      puts "#{mode}: create app #{@options[:app_id]} version #{@options[:version]} for #{platforms.join(", ")}"
      platforms.each do |platform|
        current = existing.find { |item| item.dig("attributes", "platform").to_s.upcase == platform.upcase }
        if current
          puts "  #{platform} #{@options[:version]} already exists (#{current["id"]}); skipped"
          next
        end

        attrs = { "platform" => platform.upcase, "versionString" => @options[:version] }
        relationships = { "app" => { "data" => { "type" => "apps", "id" => @options[:app_id] } } }
        create_resource("appStoreVersions", attrs, relationships, "#{platform.upcase} #{@options[:version]}")
      end
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

    def push_config
      config = load_metadata_config
      apply_metadata_config_defaults(config)
      mode = @options[:apply] ? "APPLY" : "DRY-RUN"
      puts "#{mode}: push metadata config #{@options[:config_path]} for app #{@options[:app_id]}, version #{@options[:version]}"
      puts "Planned locales: #{planned_locales.join(", ")}"
      puts

      app_info = app_info!
      if @options[:skip_app_info]
        puts "App Info Config"
        puts "  skipped by --skip-app-info"
        puts
      else
        push_app_info_config(app_info["id"], config.fetch("app_info", {}))
      end
      push_version_localization_config(config.fetch("version_localizations", {}))
      if @options[:skip_review_notes]
        puts "App Review Notes Config"
        puts "  skipped by --skip-review-notes"
        puts
      else
        push_review_notes_config(config.fetch("review_notes", {}))
      end
      if @options[:skip_subscriptions]
        puts "Subscription Config"
        puts "  skipped by --skip-subscriptions"
        puts
      else
        push_subscription_config(config)
      end
    end

    def load_metadata_config
      path = Pathname(@options[:config_path])
      raise Error, "Metadata config not found: #{path}" unless path.file?

      YAML.safe_load(path.read, aliases: true) || {}
    rescue Psych::SyntaxError => e
      raise Error, "Invalid metadata YAML #{path}: #{e.message}"
    end

    def apply_metadata_config_defaults(config)
      config_app_id = config["app_id"].to_s.strip
      config_version = config["version"].to_s.strip
      @options[:app_id] = config_app_id unless config_app_id.empty? || @options[:app_id] != DEFAULT_APP_ID
      @options[:version] = config_version unless config_version.empty? || @options[:version] != DEFAULT_VERSION
      @options[:planned_locales] = Array(config["planned_locales"]).map(&:to_s) if @options[:planned_locales].empty? && config["planned_locales"]
      @options[:future_locales] = Array(config["future_locales"]).map(&:to_s) if @options[:future_locales].empty? && config["future_locales"]
    end

    def push_app_info_config(app_info_id, localizations)
      puts "App Info Config"
      existing = app_info_localizations(app_info_id)
      each_locale_attrs(localizations) do |locale, attrs|
        target = find_locale(existing, locale)
        if target && @options[:shared_create_only]
          puts "  app info #{locale} exists; preserved by --shared-create-only"
          next
        end
        upsert_localization(
          type: "appInfoLocalizations",
          target: target,
          locale: locale,
          attrs: attrs,
          fields: APP_INFO_FIELDS,
          relationships: { "appInfo" => { "data" => { "type" => "appInfos", "id" => app_info_id } } },
          label: "app info #{locale}"
        )
      end
      puts
    end

    def push_version_localization_config(localizations)
      puts "Version Localization Config"
      versions = app_store_versions
      raise Error, "No App Store versions found for #{@options[:version]}; run create-version first." if versions.empty?

      versions.each do |version|
        version_attrs = version["attributes"] || {}
        label = "#{version_attrs["platform"]} #{version_attrs["versionString"]}"
        existing = version_localizations(version["id"])
        each_locale_attrs(localizations) do |locale, attrs|
          target = find_locale(existing, locale)
          upsert_localization(
            type: "appStoreVersionLocalizations",
            target: target,
            locale: locale,
            attrs: attrs,
            fields: VERSION_FIELDS,
            relationships: { "appStoreVersion" => { "data" => { "type" => "appStoreVersions", "id" => version["id"] } } },
            label: "#{label} #{locale}"
          )
        end
      end
      puts
    end

    def push_subscription_config(config)
      puts "Subscription Config"
      group_config = config.fetch("subscription_group", {})
      group = configured_subscription_group(group_config)
      if group && group_config["localizations"]
        existing = subscription_group_localizations(group["id"])
        each_locale_attrs(group_config["localizations"]) do |locale, attrs|
          target = find_locale(existing, locale)
          if target && @options[:shared_create_only]
            puts "  subscription group #{locale} exists; preserved by --shared-create-only"
            next
          end
          upsert_localization(
            type: "subscriptionGroupLocalizations",
            target: target,
            locale: locale,
            attrs: attrs,
            fields: SUBSCRIPTION_GROUP_LOCALIZATION_FIELDS,
            relationships: { "subscriptionGroup" => { "data" => { "type" => "subscriptionGroups", "id" => group["id"] } } },
            label: "subscription group #{locale}"
          )
        end
      end

      subscriptions_by_product_id.each do |product_id, subscription|
        product_config = config.fetch("subscriptions", {}).fetch(product_id, nil)
        next unless product_config && product_config["localizations"]

        existing = subscription_localizations(subscription["id"])
        each_locale_attrs(product_config["localizations"]) do |locale, attrs|
          target = find_locale(existing, locale)
          if target && @options[:shared_create_only]
            puts "  subscription #{product_id} #{locale} exists; preserved by --shared-create-only"
            next
          end
          upsert_localization(
            type: "subscriptionLocalizations",
            target: target,
            locale: locale,
            attrs: attrs,
            fields: SUBSCRIPTION_LOCALIZATION_FIELDS,
            relationships: { "subscription" => { "data" => { "type" => "subscriptions", "id" => subscription["id"] } } },
            label: "subscription #{product_id} #{locale}"
          )
        end
      end
      puts
    end

    def push_review_notes_config(config)
      puts "App Review Notes Config"
      profiles = config.fetch("profiles", {}).to_h
      platform_profiles = config.fetch("platform_profiles", {}).to_h
      if profiles.empty? || platform_profiles.empty?
        puts "  no review notes profiles configured; skipped"
        puts
        return
      end

      app_store_versions.each do |version|
        platform = version.dig("attributes", "platform").to_s
        profile_name = platform_profiles[platform].to_s
        next if profile_name.empty?

        notes = profiles[profile_name].to_s.strip
        raise Error, "Missing App Review Notes profile #{profile_name.inspect} for #{platform}" if notes.empty?

        detail = app_review_detail(version["id"])
        raise Error, "Missing App Review Detail for #{platform} #{@options[:version]}" unless detail

        desired = { "notes" => notes, "demoAccountRequired" => false }
        changed = desired.each_with_object({}) do |(field, value), result|
          result[field] = value unless detail.dig("attributes", field) == value
        end
        patch_resource(
          "appStoreReviewDetails",
          detail["id"],
          changed,
          "#{platform} #{@options[:version]} review notes profile=#{profile_name}"
        )
      end
      puts
    end

    def app_info!
      infos = client.collection("/v1/apps/#{@options[:app_id]}/appInfos", "limit" => "20")
      raise Error, "No appInfo found for app #{@options[:app_id]}" if infos.empty?

      editable = infos.find do |info|
        attrs = info["attributes"] || {}
        attrs["appStoreState"] == "PREPARE_FOR_SUBMISSION" || attrs["state"] == "PREPARE_FOR_SUBMISSION"
      end
      editable || infos.first
    end

    def app_info_localizations(app_info_id)
      client.collection(
        "/v1/appInfos/#{app_info_id}/appInfoLocalizations",
        "fields[appInfoLocalizations]" => (APP_INFO_FIELDS + ["locale"]).join(","),
        "limit" => "200"
      )
    end

    def app_store_versions
      versions = app_store_versions_for(@options[:version])
      platforms = @options[:platforms]
      return versions if platforms.empty?

      versions.select { |version| platforms.include?(version.dig("attributes", "platform").to_s.upcase) }
    end

    def app_store_versions_for(version_string)
      client.collection(
        "/v1/apps/#{@options[:app_id]}/appStoreVersions",
        "filter[versionString]" => version_string,
        "limit" => "200"
      )
    end

    def localization_snapshot(localizations, fields)
      localizations.sort_by { |item| item.dig("attributes", "locale").to_s }.each_with_object({}) do |item, result|
        attrs = item["attributes"] || {}
        locale = attrs["locale"].to_s
        result[locale] = fields.each_with_object({ "id" => item["id"] }) do |field, values|
          values[field] = attrs[field] unless attrs[field].nil?
        end
      end
    end

    def subscription_snapshot
      subscription_groups.map do |group|
        attrs = group["attributes"] || {}
        {
          "id" => group["id"],
          "reference_name" => attrs["referenceName"],
          "localizations" => localization_snapshot(subscription_group_localizations(group["id"]), SUBSCRIPTION_GROUP_LOCALIZATION_FIELDS),
          "subscriptions" => subscriptions(group["id"]).sort_by { |item| item.dig("attributes", "productId").to_s }.map do |subscription|
            subscription_attrs = subscription["attributes"] || {}
            {
              "id" => subscription["id"],
              "product_id" => subscription_attrs["productId"],
              "state" => subscription_attrs["state"],
              "period" => subscription_attrs["subscriptionPeriod"],
              "family_sharing" => subscription_attrs["familySharable"],
              "localizations" => localization_snapshot(subscription_localizations(subscription["id"]), SUBSCRIPTION_LOCALIZATION_FIELDS)
            }
          end
        }
      end
    end

    def version_localizations(version_id)
      client.collection(
        "/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations",
        "fields[appStoreVersionLocalizations]" => (VERSION_FIELDS + ["locale"]).join(","),
        "limit" => "200"
      )
    end

    def app_review_detail(version_id)
      client.get(
        "/v1/appStoreVersions/#{version_id}/appStoreReviewDetail",
        "fields[appStoreReviewDetails]" => "demoAccountRequired,notes"
      )["data"]
    rescue Error => e
      warn "  warning: could not read App Review Detail for #{version_id}: #{e.message}"
      nil
    end

    def review_detail_snapshot(version_id)
      detail = app_review_detail(version_id)
      return nil unless detail

      {
        "id" => detail["id"],
        "demo_account_required" => detail.dig("attributes", "demoAccountRequired"),
        "notes" => detail.dig("attributes", "notes")
      }
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

    def print_review_details(versions)
      puts "App Review Details"
      versions.each do |version|
        platform = version.dig("attributes", "platform").to_s
        detail = app_review_detail(version["id"])
        if detail
          notes = detail.dig("attributes", "notes").to_s
          checksum = notes.empty? ? "none" : Digest::SHA256.hexdigest(notes)
          puts "  - #{platform} id=#{detail["id"]} " \
               "demoAccountRequired=#{detail.dig("attributes", "demoAccountRequired")} " \
               "notes=#{length_summary(notes)} sha256=#{checksum}"
        else
          puts "  - #{platform} missing"
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

    def print_subscription_matrix
      puts "Subscription Matrix"
      groups = subscription_groups
      if groups.empty?
        puts "  no subscription groups found"
        puts
        return
      end

      groups.each do |group|
        group_attrs = group["attributes"] || {}
        puts "  - group #{group["id"]} referenceName=#{summary(group_attrs["referenceName"])}"
        print_subscription_group_localization_matrix(group)
        print_subscription_products_matrix(group)
      end
      puts
    end

    def print_subscription_group_localization_matrix(group)
      localizations = subscription_group_localizations(group["id"])
      present = localizations.map { |loc| loc.dig("attributes", "locale") }.compact.sort
      puts "      group localizations: #{present.join(", ")}"
      print_locale_gaps("subscription group", present, indent: "      ")
      localizations.sort_by { |loc| loc.dig("attributes", "locale").to_s }.each do |loc|
        attrs = loc["attributes"] || {}
        locale = attrs["locale"].to_s
        missing = missing_fields(attrs, SUBSCRIPTION_GROUP_LOCALIZATION_FIELDS)
        fields = missing.empty? ? "ok" : "missing:#{missing.join(",")}"
        custom_app_name = attrs["customAppName"].nil? || attrs["customAppName"].to_s.empty? ? "default-app-name" : summary(attrs["customAppName"])
        puts "        #{locale} #{locale_state(locale)} state=#{attrs["state"] || "unknown"} " \
             "fields=#{fields} name=#{summary(attrs["name"])} customAppName=#{custom_app_name}"
      end
    end

    def print_subscription_products_matrix(group)
      subscriptions(group["id"]).sort_by { |sub| sub.dig("attributes", "productId").to_s }.each do |sub|
        attrs = sub["attributes"] || {}
        product_id = attrs["productId"].to_s
        puts "      product #{sub["id"]} #{product_id} " \
             "period=#{attrs["subscriptionPeriod"] || "unknown"} " \
             "state=#{attrs["state"] || "unknown"} " \
             "familySharable=#{attrs["familySharable"].nil? ? "unknown" : attrs["familySharable"]} " \
             "groupLevel=#{attrs["groupLevel"] || "unknown"}"
        print_subscription_localization_matrix(sub)
      end
    end

    def print_subscription_localization_matrix(subscription)
      localizations = subscription_localizations(subscription["id"])
      present = localizations.map { |loc| loc.dig("attributes", "locale") }.compact.sort
      puts "        localizations: #{present.join(", ")}"
      print_locale_gaps("subscription #{subscription.dig("attributes", "productId")}", present, indent: "        ")
      localizations.sort_by { |loc| loc.dig("attributes", "locale").to_s }.each do |loc|
        attrs = loc["attributes"] || {}
        locale = attrs["locale"].to_s
        missing = missing_fields(attrs, SUBSCRIPTION_LOCALIZATION_FIELDS)
        fields = missing.empty? ? "ok" : "missing:#{missing.join(",")}"
        description = attrs["description"].to_s
        description_status = description.empty? ? "missing" : "#{description.length}/#{SUBSCRIPTION_DESCRIPTION_LIMIT}"
        description_status += ":over" if description.length > SUBSCRIPTION_DESCRIPTION_LIMIT
        puts "          #{locale} #{locale_state(locale)} state=#{attrs["state"] || "unknown"} " \
             "fields=#{fields} name=#{summary(attrs["name"])} description=#{description_status}"
      end
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

    def subscription_groups
      client.collection(
        "/v1/apps/#{@options[:app_id]}/subscriptionGroups",
        "fields[subscriptionGroups]" => "referenceName",
        "limit" => "200"
      )
    rescue Error => e
      warn "  warning: could not read subscription groups: #{e.message}"
      []
    end

    def configured_subscription_group(group_config)
      groups = subscription_groups
      return nil if groups.empty?

      reference_name = group_config["reference_name"].to_s.strip
      return groups.first if reference_name.empty?

      groups.find { |group| group.dig("attributes", "referenceName").to_s == reference_name } || groups.first
    end

    def subscriptions_by_product_id
      subscription_groups.each_with_object({}) do |group, result|
        subscriptions(group["id"]).each do |subscription|
          product_id = subscription.dig("attributes", "productId").to_s
          result[product_id] = subscription unless product_id.empty?
        end
      end
    end

    def subscription_group_localizations(group_id)
      client.collection(
        "/v1/subscriptionGroups/#{group_id}/subscriptionGroupLocalizations",
        "fields[subscriptionGroupLocalizations]" => "name,customAppName,locale,state",
        "limit" => "200"
      )
    rescue Error => e
      warn "  warning: could not read subscription group localizations for #{group_id}: #{e.message}"
      []
    end

    def subscriptions(group_id)
      client.collection(
        "/v1/subscriptionGroups/#{group_id}/subscriptions",
        "fields[subscriptions]" => "name,productId,familySharable,state,subscriptionPeriod,groupLevel",
        "limit" => "200"
      )
    rescue Error => e
      warn "  warning: could not read subscriptions for #{group_id}: #{e.message}"
      []
    end

    def subscription_localizations(subscription_id)
      client.collection(
        "/v1/subscriptions/#{subscription_id}/subscriptionLocalizations",
        "fields[subscriptionLocalizations]" => "name,description,locale,state",
        "limit" => "200"
      )
    rescue Error => e
      warn "  warning: could not read subscription localizations for #{subscription_id}: #{e.message}"
      []
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

    def each_locale_attrs(localizations)
      localizations.to_h.sort.each do |locale, attrs|
        next unless @options[:locales].empty? || @options[:locales].include?(locale.to_s)

        yield locale.to_s, attrs.to_h
      end
    end

    def upsert_localization(type:, target:, locale:, attrs:, fields:, relationships:, label:)
      desired = desired_attributes(attrs, fields)
      warn_config_missing(desired, fields, label)
      if target
        changed = desired.each_with_object({}) do |(field, value), result|
          result[field] = value unless target.dig("attributes", field) == value
        end
        patch_resource(type, target["id"], changed, label)
      else
        create_resource(type, desired.merge("locale" => locale), relationships, label)
      end
    end

    def desired_attributes(attrs, fields)
      attrs.each_with_object({}) do |(key, value), result|
        field = key.to_s
        next unless fields.include?(field)
        next if value.nil?

        result[field] = value
      end
    end

    def warn_config_missing(attrs, fields, label)
      missing = fields.select { |field| attrs[field].nil? || attrs[field].to_s.empty? }
      return if missing.empty?

      warn "  warning: metadata config #{label} has empty fields: #{missing.join(", ")}"
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
