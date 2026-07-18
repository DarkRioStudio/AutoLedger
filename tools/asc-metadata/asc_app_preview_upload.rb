#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "optparse"
require "pathname"

require_relative "asc_screenshot_upload"

module ASCAppPreviewUpload
  DEFAULT_OPTIONS = {
    app_id: ASCMetadata::DEFAULT_APP_ID,
    version: ASCMetadata::DEFAULT_VERSION,
    platform: "IOS",
    target_locale: "en-US",
    preview_type: "IPHONE_65",
    file: nil,
    poster_frame_time_code: nil,
    timeout_seconds: 900,
    poll_seconds: 10,
    apply: false
  }.freeze

  class Error < StandardError; end

  class Runner
    def initialize(argv)
      @options = DEFAULT_OPTIONS.dup
      parse!(argv)
    end

    def run
      file = preview_file
      mode = @options[:apply] ? "APPLY" : "DRY-RUN"
      puts "#{mode}: replace App Preview #{@options[:target_locale]} #{@options[:preview_type]} " \
           "for app #{@options[:app_id]}, version #{@options[:version]}, platform #{@options[:platform]}"

      version = app_store_version
      localization = target_localization(version)
      set = find_preview_set(localization)
      existing = set ? app_previews(set["id"]) : []
      checksum = Digest::MD5.file(file).hexdigest
      matched = existing.find { |preview| preview.dig("attributes", "sourceFileChecksum") == checksum }

      puts "VERSION id=#{version["id"]} localization=#{localization["id"]} " \
           "set=#{set ? set["id"] : "missing"} existing=#{existing.length} file=#{file.basename}"

      if matched
        state = preview_state(matched)
        poster = matched.dig("attributes", "previewFrameTimeCode")
        puts "  existing checksum match id=#{matched["id"]} state=#{state || "unknown"} " \
             "poster=#{poster || "unset"}"
        matched = wait_for_preview(matched["id"]) if @options[:apply] && state != "COMPLETE"
        configure_poster_frame(matched)
        delete_stale(existing, keep_id: matched["id"]) if @options[:apply]
        return
      end

      unless @options[:apply]
        puts "  would create preview set" unless set
        puts "  would upload #{file.basename} before deleting #{existing.length} stale preview(s)"
        return
      end

      if existing.length >= 3
        raise Error, "Preview set already contains #{existing.length} files; refusing to delete before a verified replacement is available"
      end

      set ||= create_preview_set(localization)
      uploaded = upload_preview(set["id"], file)
      uploaded = wait_for_preview(uploaded["id"])
      configure_poster_frame(uploaded)
      delete_stale(existing, keep_id: uploaded["id"])
      puts "  replacement complete id=#{uploaded["id"]} checksum=#{checksum}"
    end

    private

    def parse!(argv)
      OptionParser.new do |opts|
        opts.banner = "Usage: ruby tools/asc-metadata/asc_app_preview_upload.rb --file PATH [options]"
        opts.on("--app-id ID", "ASC app Apple ID") { |v| @options[:app_id] = v }
        opts.on("--version VERSION", "App Store version string") { |v| @options[:version] = v }
        opts.on("--platform PLATFORM", "App Store platform, default IOS") { |v| @options[:platform] = v.upcase }
        opts.on("--target-locale LOCALE", "ASC locale, e.g. en-US") { |v| @options[:target_locale] = v }
        opts.on("--preview-type TYPE", "ASC PreviewType, default IPHONE_65") { |v| @options[:preview_type] = v.upcase }
        opts.on("--file PATH", "Rendered App Preview MP4") { |v| @options[:file] = v }
        opts.on("--poster-frame-time-code CODE", "Poster frame timecode HH:MM:SS:FF, e.g. 00:00:01:12") do |v|
          @options[:poster_frame_time_code] = validate_time_code(v)
        end
        opts.on("--timeout-seconds N", Integer, "Processing timeout, default 900") { |v| @options[:timeout_seconds] = v }
        opts.on("--poll-seconds N", Integer, "Processing poll interval, default 10") { |v| @options[:poll_seconds] = v }
        opts.on("--apply", "Write changes to App Store Connect") { @options[:apply] = true }
        opts.on("-h", "--help", "Show help") { abort opts.to_s }
      end.parse!(argv)
    end

    def validate_time_code(value)
      match = /\A(\d{2}):(\d{2}):(\d{2}):(\d{2})\z/.match(value.to_s)
      unless match && match[2].to_i < 60 && match[3].to_i < 60 && match[4].to_i < 60
        raise OptionParser::InvalidArgument,
              "poster frame timecode must use ASC's HH:MM:SS:FF format with minutes, seconds, and frames below 60"
      end

      value
    end

    def client
      @client ||= ASCMetadata::Client.new(
        issuer_id: required_env("ASC_ISSUER_ID"),
        key_id: required_env("ASC_KEY_ID"),
        private_key_pem: private_key_pem
      )
    end

    def direct_client
      @direct_client ||= ASCScreenshotUpload::DirectClient.new(client)
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

    def preview_file
      path = @options[:file].to_s.strip
      raise Error, "Missing --file PATH" if path.empty?

      file = Pathname(path).expand_path
      raise Error, "App Preview file not found: #{file}" unless file.file?

      file
    end

    def app_store_version
      versions = client.collection(
        "/v1/apps/#{@options[:app_id]}/appStoreVersions",
        "filter[versionString]" => @options[:version],
        "filter[platform]" => @options[:platform],
        "fields[appStoreVersions]" => "platform,versionString,appStoreState",
        "limit" => "200"
      )
      version = versions.find { |item| item.dig("attributes", "platform") == @options[:platform] }
      return version if version

      raise Error, "Missing #{@options[:platform]} #{@options[:version]} App Store version"
    end

    def target_localization(version)
      localizations = client.collection(
        "/v1/appStoreVersions/#{version["id"]}/appStoreVersionLocalizations",
        "fields[appStoreVersionLocalizations]" => "locale",
        "limit" => "200"
      )
      localization = localizations.find { |loc| loc.dig("attributes", "locale") == @options[:target_locale] }
      return localization if localization

      raise Error, "Missing #{@options[:target_locale]} localization for #{@options[:platform]}"
    end

    def find_preview_set(localization)
      sets = client.collection(
        "/v1/appStoreVersionLocalizations/#{localization["id"]}/appPreviewSets",
        "fields[appPreviewSets]" => "previewType",
        "limit" => "200"
      )
      sets.find { |set| set.dig("attributes", "previewType") == @options[:preview_type] }
    end

    def create_preview_set(localization)
      created = client.post("/v1/appPreviewSets", {
        "data" => {
          "type" => "appPreviewSets",
          "attributes" => { "previewType" => @options[:preview_type] },
          "relationships" => {
            "appStoreVersionLocalization" => {
              "data" => { "type" => "appStoreVersionLocalizations", "id" => localization["id"] }
            }
          }
        }
      })["data"]
      puts "  created preview set id=#{created["id"]}"
      created
    end

    def app_previews(set_id)
      client.collection(
        "/v1/appPreviewSets/#{set_id}/appPreviews",
        "fields[appPreviews]" => "fileName,fileSize,sourceFileChecksum,mimeType,previewFrameTimeCode," \
                                 "previewFrameImage,assetDeliveryState,videoDeliveryState",
        "limit" => "50"
      )
    end

    def upload_preview(set_id, file)
      reservation = client.post("/v1/appPreviews", {
        "data" => {
          "type" => "appPreviews",
          "attributes" => {
            "fileName" => file.basename.to_s,
            "fileSize" => file.size
          },
          "relationships" => {
            "appPreviewSet" => {
              "data" => { "type" => "appPreviewSets", "id" => set_id }
            }
          }
        }
      })["data"]
      operations = Array(reservation.dig("attributes", "uploadOperations"))
      raise Error, "No upload operations returned for #{file}" if operations.empty?

      puts "  reserved #{file.basename} id=#{reservation["id"]} operations=#{operations.length}"
      direct_client.upload_operations(operations, file)
      checksum = Digest::MD5.file(file).hexdigest
      committed = client.patch("/v1/appPreviews/#{reservation["id"]}", {
        "data" => {
          "type" => "appPreviews",
          "id" => reservation["id"],
          "attributes" => {
            "sourceFileChecksum" => checksum,
            "uploaded" => true
          }
        }
      })["data"]
      puts "  committed id=#{committed["id"]} state=#{preview_state(committed) || "unknown"}"
      committed
    end

    def wait_for_preview(preview_id)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @options[:timeout_seconds]
      last_state = nil
      loop do
        preview = client.get(
          "/v1/appPreviews/#{preview_id}",
          "fields[appPreviews]" => "fileName,sourceFileChecksum,previewFrameTimeCode,previewFrameImage," \
                                   "assetDeliveryState,videoDeliveryState"
        )["data"]
        state = preview_state(preview)
        if state != last_state
          puts "  processing id=#{preview_id} state=#{state || "unknown"}"
          last_state = state
        end
        return preview if state == "COMPLETE"
        if state == "FAILED"
          details = preview_errors(preview)
          direct_client.delete("/v1/appPreviews/#{preview_id}")
          raise Error, "App Preview processing failed: #{details}"
        end
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          raise Error, "Timed out waiting for App Preview #{preview_id}; last state=#{state || "unknown"}"
        end

        sleep @options[:poll_seconds]
      end
    end

    def configure_poster_frame(preview)
      desired = @options[:poster_frame_time_code]
      return preview unless desired

      current = preview.dig("attributes", "previewFrameTimeCode")
      frame_state = preview_frame_state(preview)
      if current == desired && frame_state == "COMPLETE"
        puts "  poster frame verified id=#{preview["id"]} timecode=#{desired} state=COMPLETE"
        return preview
      end

      unless @options[:apply]
        puts "  would set poster frame id=#{preview["id"]} from=#{current || "unset"} to=#{desired}"
        return preview
      end

      if current != desired
        client.patch("/v1/appPreviews/#{preview["id"]}", {
          "data" => {
            "type" => "appPreviews",
            "id" => preview["id"],
            "attributes" => { "previewFrameTimeCode" => desired }
          }
        })
        puts "  requested poster frame id=#{preview["id"]} timecode=#{desired}"
      end

      wait_for_poster_frame(preview["id"], desired)
    end

    def wait_for_poster_frame(preview_id, desired)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @options[:timeout_seconds]
      last_status = nil
      loop do
        preview = client.get(
          "/v1/appPreviews/#{preview_id}",
          "fields[appPreviews]" => "previewFrameTimeCode,previewFrameImage,videoDeliveryState"
        )["data"]
        current = preview.dig("attributes", "previewFrameTimeCode")
        state = preview_frame_state(preview)
        status = "timecode=#{current || "unset"} state=#{state || "unknown"}"
        if status != last_status
          puts "  poster processing id=#{preview_id} #{status}"
          last_status = status
        end
        if current == desired && state == "COMPLETE"
          puts "  poster frame verified id=#{preview_id} timecode=#{desired} state=COMPLETE"
          return preview
        end
        if state == "FAILED"
          raise Error, "Poster frame processing failed for App Preview #{preview_id}"
        end
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          raise Error, "Timed out waiting for poster frame #{preview_id}; last #{status}"
        end

        sleep @options[:poll_seconds]
      end
    end

    def preview_frame_state(preview)
      preview.dig("attributes", "previewFrameImage", "state", "state")
    end

    def preview_state(preview)
      attrs = preview["attributes"] || {}
      attrs.dig("videoDeliveryState", "state") || attrs.dig("assetDeliveryState", "state")
    end

    def preview_errors(preview)
      attrs = preview["attributes"] || {}
      state = attrs["videoDeliveryState"] || attrs["assetDeliveryState"] || {}
      errors = Array(state["errors"]).map { |error| [error["code"], error["description"]].compact.join(": ") }
      errors.empty? ? "unknown processing error" : errors.join("; ")
    end

    def delete_stale(previews, keep_id:)
      previews.reject { |preview| preview["id"] == keep_id }.each do |preview|
        direct_client.delete("/v1/appPreviews/#{preview["id"]}")
        puts "  deleted stale preview id=#{preview["id"]}"
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  ASCAppPreviewUpload::Runner.new(ARGV).run
end
