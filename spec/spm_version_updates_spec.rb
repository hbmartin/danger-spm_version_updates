# frozen_string_literal: true

require "simplecov"
SimpleCov.start

require "simplecov-cobertura"
SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter

require File.expand_path("spec_helper", __dir__)

module Danger
  describe Danger::DangerSpmVersionUpdates do
    it "is a plugin" do
      expect(described_class.new(nil)).to be_a Danger::Plugin
    end

    describe "with Dangerfile" do
      before do
        @dangerfile = testing_dangerfile
        @my_plugin = @dangerfile.spm_version_updates

        # mock the PR data
        # you can then use this, eg. github.pr_author, later in the spec
        json = File.read("#{File.dirname(__FILE__)}/support/fixtures/github_pr.json") # example json: `curl https://api.github.com/repos/danger/danger-plugin-template/pulls/18 > github_pr.json`
        allow(@my_plugin.github).to receive(:pr_json).and_return(json)
      end

      it "Does not report pre-release versions by default" do
        allow(@my_plugin).to receive(:git_versions)
          .and_return [
            Semantic::Version.new("12.1.6"),
            Semantic::Version.new("12.2.0-beta.1"),
            Semantic::Version.new("12.2.0-beta.2"),
          ].sort.reverse

        @my_plugin.check_when_exact = true
        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/ExactVersion.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq([])
      end

      it "Does report new versions for exact versions when configured" do
        allow(@my_plugin).to receive(:git_versions)
          .and_return [
            Semantic::Version.new("12.1.6"),
            Semantic::Version.new("12.1.7"),
          ].sort.reverse

        @my_plugin.check_when_exact = true
        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/ExactVersion.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq(
          [
            "Newer version of kean/Nuke: 12.1.7 (but this package is set to exact version 12.1.6)\n",
          ]
        )
      end

      it "Does report pre-release versions for exact versions when configured" do
        allow(@my_plugin).to receive(:git_versions)
          .and_return [
            Semantic::Version.new("12.1.6"),
            Semantic::Version.new("12.2.0-beta.2"),
          ].sort.reverse

        @my_plugin.check_when_exact = true
        @my_plugin.report_pre_releases = true
        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/ExactVersion.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq(
          [
            "Newer version of kean/Nuke: 12.2.0-beta.2 (but this package is set to exact version 12.1.6)\n",
          ]
        )
      end

      it "Does report new versions for up to next major" do
        allow(@my_plugin).to receive(:git_versions)
          .and_return [
            Semantic::Version.new("12.1.6"),
            Semantic::Version.new("12.1.7"),
          ].sort.reverse

        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/UpToNextMajor.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq(
          [
            "Newer version of kean/Nuke: 12.1.7",
          ]
        )
      end

      it "Reports pre-release versions for up to next major when configured" do
        allow(@my_plugin).to receive(:git_versions)
          .and_return [
            Semantic::Version.new("12.1.6"),
            Semantic::Version.new("12.2.0-beta.2"),
          ].sort.reverse

        @my_plugin.check_when_exact = true
        @my_plugin.report_pre_releases = true
        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/UpToNextMajor.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq(
          [
            "Newer version of kean/Nuke: 12.2.0-beta.2",
          ]
        )
      end

      it "Does not report pre-release versions for up to next major" do
        allow(@my_plugin).to receive(:git_versions)
          .and_return [
            Semantic::Version.new("12.1.6"),
            Semantic::Version.new("12.2.0-beta.2"),
            Semantic::Version.new("13.0.0"),
          ].sort.reverse

        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/UpToNextMajor.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq([])
      end

      it "Does not report new versions for up to next major when next version is major" do
        allow(@my_plugin).to receive(:git_versions)
          .and_return [
            Semantic::Version.new("12.1.6"),
            Semantic::Version.new("13.0.0"),
          ].sort.reverse

        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/UpToNextMajor.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq([])
      end

      it "Does report new versions for up to next major when next version is major and configured" do
        allow(@my_plugin).to receive(:git_versions)
          .and_return [
            Semantic::Version.new("12.1.6"),
            Semantic::Version.new("13.0.0"),
          ].sort.reverse

        @my_plugin.report_above_maximum = true
        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/UpToNextMajor.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq(["Newest version of kean/Nuke: 13.0.0 (but this package is configured up to the next major version)\n"])
      end
    end
  end
end
