#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"

require_relative "asc_metadata"

module ASCBuildBind
  DEFAULT_OPTIONS = {
    app_id: ASCMetadata::DEFAULT_APP_ID,
    version: ASCMetadata::DEFAULT_VERSION,
    build_number: nil,
    expected_source_commit: nil,
    platforms: [],
    apply: false
  }.freeze

  class Error < StandardError; end

  class Runner
    def initialize(argv)
      @options = DEFAULT_OPTIONS.merge(platforms: [])
      parse!(argv)
    end

    def run
      validate_options!
      mode = @options[:apply] ? "APPLY" : "DRY-RUN"
      puts "#{mode}: bind build #{@options[:build_number]} to app #{@options[:app_id]} " \
           "version #{@options[:version]}"

      verify_xcode_cloud_source!
      versions = app_store_versions
      builds = eligible_builds
      raise Error, "No App Store versions selected" if versions.empty?

      planned = versions.map do |version|
        platform = version.dig("attributes", "platform").to_s
        candidates = builds.select { |build| build.fetch(:platform) == platform }
        raise Error, "Expected exactly one eligible build for #{platform}; found #{candidates.length}" unless candidates.length == 1

        build = candidates.first
        current_id = current_build_id(version["id"])
        puts "  #{platform} versionId=#{version["id"]} buildId=#{build.fetch(:id)} " \
             "current=#{current_id || "none"} uploaded=#{build.fetch(:uploaded_date)}"
        [version, build, current_id]
      end

      unless @options[:apply]
        planned.each do |version, build, current_id|
          next if current_id == build.fetch(:id)

          puts "    would bind #{version.dig("attributes", "platform")} to build #{@options[:build_number]}"
        end
        return
      end

      planned.each do |version, build, current_id|
        if current_id == build.fetch(:id)
          puts "    #{version.dig("attributes", "platform")} already bound; skipped"
          next
        end

        client.patch("/v1/appStoreVersions/#{version["id"]}/relationships/build", {
          "data" => { "type" => "builds", "id" => build.fetch(:id) }
        })
        puts "    bound #{version.dig("attributes", "platform")} to build #{@options[:build_number]}"
      end

      planned.each do |version, build, _current_id|
        actual = current_build_id(version["id"])
        unless actual == build.fetch(:id)
          raise Error, "Build readback mismatch for #{version.dig("attributes", "platform")}: #{actual || "none"}"
        end
        puts "    verified #{version.dig("attributes", "platform")} buildId=#{actual}"
      end
    end

    private

    def parse!(argv)
      OptionParser.new do |opts|
        opts.banner = "Usage: ruby tools/asc-metadata/asc_build_bind.rb --build-number N --expected-source-commit SHA [options]"
        opts.on("--app-id ID", "ASC app Apple ID") { |v| @options[:app_id] = v }
        opts.on("--version VERSION", "App Store version string") { |v| @options[:version] = v }
        opts.on("--build-number N", "Xcode Cloud / TestFlight build number") { |v| @options[:build_number] = v }
        opts.on("--expected-source-commit SHA", "Required exact Xcode Cloud source commit SHA") do |v|
          @options[:expected_source_commit] = v.downcase
        end
        opts.on("--platform PLATFORM", "Restrict platform; can be repeated") { |v| @options[:platforms] << v.upcase }
        opts.on("--apply", "Write build relationships to App Store Connect") { @options[:apply] = true }
        opts.on("-h", "--help", "Show help") { abort opts.to_s }
      end.parse!(argv)
    end

    def validate_options!
      raise Error, "Missing --build-number" if @options[:build_number].to_s.strip.empty?
      sha = @options[:expected_source_commit].to_s
      raise Error, "Missing --expected-source-commit" if sha.empty?
      raise Error, "Expected a full 40-character source commit SHA" unless /\A[0-9a-f]{40}\z/.match?(sha)
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
      raise Error, "Missing #{name}" if value.empty?

      value
    end

    def verify_xcode_cloud_source!
      product = client.get(
        "/v1/apps/#{@options[:app_id]}/ciProduct",
        "fields[ciProducts]" => "name"
      )["data"]
      raise Error, "Missing Xcode Cloud product" unless product

      runs = client.collection(
        "/v1/ciProducts/#{product["id"]}/buildRuns",
        "fields[ciBuildRuns]" => "number,sourceCommit,completionStatus,finishedDate",
        "sort" => "-number",
        "limit" => "200"
      )
      run = runs.find { |item| item.dig("attributes", "number").to_s == @options[:build_number].to_s }
      raise Error, "Missing Xcode Cloud run #{@options[:build_number]}" unless run

      attrs = run["attributes"] || {}
      commit = attrs.dig("sourceCommit", "commitSha").to_s.downcase
      raise Error, "Xcode Cloud run #{@options[:build_number]} is #{attrs["completionStatus"]}" unless attrs["completionStatus"] == "SUCCEEDED"
      unless commit == @options[:expected_source_commit]
        raise Error, "Xcode Cloud source mismatch: expected #{@options[:expected_source_commit]}, got #{commit || "missing"}"
      end

      puts "  Xcode Cloud run=#{attrs["number"]} source=#{commit} status=SUCCEEDED finished=#{attrs["finishedDate"]}"
    end

    def app_store_versions
      versions = client.collection(
        "/v1/apps/#{@options[:app_id]}/appStoreVersions",
        "filter[versionString]" => @options[:version],
        "fields[appStoreVersions]" => "platform,versionString,appStoreState",
        "limit" => "20"
      )
      versions.select! { |version| @options[:platforms].include?(version.dig("attributes", "platform")) } unless @options[:platforms].empty?
      versions.each do |version|
        state = version.dig("attributes", "appStoreState")
        raise Error, "#{version.dig("attributes", "platform")} version is #{state}, not PREPARE_FOR_SUBMISSION" unless state == "PREPARE_FOR_SUBMISSION"
      end
      versions.sort_by { |version| version.dig("attributes", "platform").to_s }
    end

    def eligible_builds
      response = client.get(
        "/v1/builds",
        "filter[app]" => @options[:app_id],
        "filter[preReleaseVersion.version]" => @options[:version],
        "filter[version]" => @options[:build_number],
        "fields[builds]" => "version,uploadedDate,processingState,expired,buildAudienceType," \
                            "usesNonExemptEncryption,preReleaseVersion",
        "fields[preReleaseVersions]" => "version,platform",
        "include" => "preReleaseVersion",
        "limit" => "200"
      )
      platforms = Array(response["included"]).select { |item| item["type"] == "preReleaseVersions" }.to_h do |item|
        [item["id"], item.dig("attributes", "platform")]
      end
      Array(response["data"]).filter_map do |build|
        attrs = build["attributes"] || {}
        next unless attrs["version"].to_s == @options[:build_number].to_s
        next unless attrs["processingState"] == "VALID"
        next unless attrs["expired"] == false
        next unless attrs["buildAudienceType"] == "APP_STORE_ELIGIBLE"
        next unless attrs["usesNonExemptEncryption"] == false

        prerelease_id = build.dig("relationships", "preReleaseVersion", "data", "id")
        {
          id: build["id"],
          platform: platforms[prerelease_id].to_s,
          uploaded_date: attrs["uploadedDate"]
        }
      end
    end

    def current_build_id(version_id)
      client.get("/v1/appStoreVersions/#{version_id}/relationships/build")["data"]&.fetch("id", nil)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  ASCBuildBind::Runner.new(ARGV).run
end
