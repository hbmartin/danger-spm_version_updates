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
        allow(Git).to receive(:version_tags)
          .and_return [
            Semantic::Version.new("12.1.6"),
            Semantic::Version.new("12.2.0-beta.1"),
            Semantic::Version.new("12.2.0-beta.2"),
          ].sort.reverse

        @my_plugin.check_when_exact = true
        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/ExactVersion.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq([])
      end

      it "Reports new versions for exact versions when configured" do
        allow(Git).to receive(:version_tags)
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

      it "Reports pre-release versions for exact versions when configured" do
        allow(Git).to receive(:version_tags)
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

      it "Reports new versions for up to next major" do
        allow(Git).to receive(:version_tags)
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
        allow(Git).to receive(:version_tags)
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
        allow(Git).to receive(:version_tags)
          .and_return [
            Semantic::Version.new("12.1.6"),
            Semantic::Version.new("12.2.0-beta.2"),
            Semantic::Version.new("13.0.0"),
          ].sort.reverse

        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/UpToNextMajor.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq([])
      end

      it "Does not report new versions for up to next major when next version is major" do
        allow(Git).to receive(:version_tags)
          .and_return [
            Semantic::Version.new("12.1.6"),
            Semantic::Version.new("13.0.0"),
          ].sort.reverse

        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/UpToNextMajor.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq([])
      end

      it "Does report new versions for up to next major when next version is major and configured" do
        allow(Git).to receive(:version_tags)
          .and_return [
            Semantic::Version.new("12.1.6"),
            Semantic::Version.new("13.0.0"),
          ].sort.reverse

        @my_plugin.report_above_maximum = true
        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/UpToNextMajor.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq(["Newest version of kean/Nuke: 13.0.0 (but this package is configured up to the next major version)\n"])
      end

      it "Reports new versions for ranges" do
        allow(Git).to receive(:version_tags)
          .and_return [
            Semantic::Version.new("13.0.0"),
            Semantic::Version.new("12.1.6"),
            Semantic::Version.new("12.1.7"),
          ].sort.reverse

        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/VersionRange.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq(
          [
            "Newer version of kean/Nuke: 12.1.7",
          ]
        )
      end

      it "Reports new versions for branches" do
        allow(Git).to receive(:branch_last_commit)
          .and_return "d658f302f56abfd7a163e3b5f44de39b780a64c2"

        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/Branch.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq(
          [
            "Newer commit available for kean/Nuke (main): d658f302f56abfd7a163e3b5f44de39b780a64c2",
          ]
        )
      end

      it "Does not report when pinned to commit" do
        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/Commit.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq([])
      end

      it "Does not crash or warn when resolved version is missing from xcodeproj" do
        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/NoResolvedVersion.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq([])
      end

      it "Does print to stderr when resolved version is missing from xcodeproj" do
        expect {
          @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/NoResolvedVersion.xcodeproj")
        }.to output(
          %r{Unable to locate the current version for kean/Nuke.*}
        ).to_stderr
      end

      it "Reports new versions for both possible Package.resolved locations" do
        allow(Git).to receive(:version_tags)
          .and_return [
            Semantic::Version.new("12.1.6"),
            Semantic::Version.new("12.1.7"),
          ].sort.reverse

        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/AlsoHasXcworkspace.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq(
          [
            "Newer version of kean/Nuke: 12.1.7",
            "Newer version of Something/Else: 12.1.7",
          ]
        )
      end

      it "Raises error when xcodeproj_path is nil" do
        expect {
          @my_plugin.check_for_updates(nil)
        }.to raise_error(Xcode::XcodeprojPathMustBeSet)
      end

      it "Raises error when no Packages.resolved are present" do
        expect {
          @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/NoPackagesResolved.xcodeproj")
        }.to raise_error(Xcode::CouldNotFindResolvedFile)
      end

      it "Reports new versions with ssh and/or .git URLs" do
        allow(Git).to receive(:version_tags)
          .and_return [
            Semantic::Version.new("12.1.6"),
            Semantic::Version.new("12.1.7"),
          ].sort.reverse

        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/MangledUrl.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq(
          [
            "Newer version of kean/Nuke: 12.1.7",
          ]
        )
      end

      it "Does not report new versions when repo was ignored" do
        allow(Git).to receive(:version_tags)
          .and_return [
            Semantic::Version.new("12.1.6"),
            Semantic::Version.new("12.1.7"),
          ].sort.reverse

        @my_plugin.ignore_repos = ["ssh://github.com/kean/Nuke.git"]
        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/UpToNextMajor.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq([])
      end

      it "Transforms git tags into version list" do
        allow_any_instance_of(Kernel).to receive(:`)
          .and_return <<-TEXT
From git@github.com:hbmartin/danger-spm_version_updates.git
4230ed95952b244d9d0b922d2b460fb73d985e02	refs/tags/0.1.0
97a139d985c2edd233017f1bb26138eea25958de	refs/tags/2.0.0
          TEXT

        expect(Git.version_tags("https://github.com/hbmartin/danger-spm_version_updates")).to eq(
          [
            Semantic::Version.new("2.0.0"),
            Semantic::Version.new("0.1.0"),
          ]
        )
      end

      it "Gathers latest commit on git branch" do
        allow_any_instance_of(Kernel).to receive(:`)
          .and_return <<-TEXT
From git@github.com:hbmartin/danger-spm_version_updates.git
5e5c3f78ff25e7678ed7d3b25d7c60eeeee47e25	HEAD
8c1a26f6c3822dc62e0feb655e0152e4f81e8ab3	refs/heads/hm/check-for-mangled-urls
5e5c3f78ff25e7678ed7d3b25d7c60eeeee47e25	refs/heads/main
ae5afe00b2d7098403dd9d87a3780cca4b4b285c	refs/pull/2/head
8c1a26f6c3822dc62e0feb655e0152e4f81e8ab3	refs/pull/3/head
a1fd1d464a6e5a76136d23b8e66a5a8c422dbeea	refs/pull/3/merge
4230ed95952b244d9d0b922d2b460fb73d985e02	refs/tags/0.1.0
97a139d985c2edd233017f1bb26138eea25958de	refs/tags/v0.1.1
5ffb986dfbb63f90de8f9854f3d0bc35eff37c56	refs/tags/v0.1.2
          TEXT

        expect(Git.branch_last_commit("https://github.com/hbmartin/danger-spm_version_updates", "main")).to eq(
          "5e5c3f78ff25e7678ed7d3b25d7c60eeeee47e25"
        )
      end

      it "Reports new versions for version=1 Package.resolved" do
        allow(Git).to receive(:version_tags)
          .and_return [
            Semantic::Version.new("3.1.3"),
          ]

        @my_plugin.check_for_updates("#{File.dirname(__FILE__)}/support/fixtures/PackageV1.xcodeproj")

        expect(@dangerfile.status_report[:warnings]).to eq(
          [
            "Newer version of gonzalezreal/NetworkImage: 3.1.3",
          ]
        )
      end
    end
  end
end
