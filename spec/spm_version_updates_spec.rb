# frozen_string_literal: true

require File.expand_path("spec_helper", __dir__)

module Danger
  describe Danger::DangerSpmVersionUpdates do
    it "is a plugin" do
      expect(described_class.new(nil)).to be_a Danger::Plugin
    end

    #
    # You should test your custom attributes and methods here
    #
    describe "with Dangerfile" do
      before do
        @dangerfile = testing_dangerfile
        @my_plugin = @dangerfile.spm_version_updates

        # mock the PR data
        # you can then use this, eg. github.pr_author, later in the spec
        json = File.read("#{File.dirname(__FILE__)}/support/fixtures/github_pr.json") # example json: `curl https://api.github.com/repos/danger/danger-plugin-template/pulls/18 > github_pr.json`
        allow(@my_plugin.github).to receive(:pr_json).and_return(json)
      end

      it "raises error if xcodeproj_path is not set" do
        expect { @my_plugin.check_for_updates }
          .to raise_error(Danger::XcodeprojPathMustBeSet)
      end

      it "Reports none without exact version matching" do
        monday_date = Date.parse("2016-07-11")
        allow(Date).to receive(:today).and_return monday_date

        @my_plugin.xcodeproj_path = "#{File.dirname(__FILE__)}/support/fixtures/Example.xcodeproj"
        @my_plugin.check_for_updates

        expect(@dangerfile.status_report[:warnings]).to eq([])
      end

      it "Reports some with exact version matching" do
        allow(@my_plugin).to receive(:git_versions).and_return false

        @my_plugin.xcodeproj_path = "#{File.dirname(__FILE__)}/support/fixtures/Example.xcodeproj"
        @my_plugin.check_when_exact = true
        @my_plugin.check_for_updates

        expect(@dangerfile.status_report[:warnings]).to eq(
          [
            "Newer version of pointfreeco/swift-snapshot-testing: 1.14.2 (but this package is set to exact version 1.13.0)\n",
            "Newer version of kean/Nuke: 12.2.0-beta.2 (but this package is set to exact version 12.1.6)\n",
            "Newer version of pointfreeco/swiftui-navigation: 1.0.3 (but this package is set to exact version 1.0.2)\n",
            "Newer version of getsentry/sentry-cocoa: 8.14.2 (but this package is set to exact version 8.12.0)\n",
            "Newer version of firebase/firebase-ios-sdk: 10.17.0 (but this package is set to exact version 10.15.0)\n",
          ]
        )
      end
    end
  end
end
