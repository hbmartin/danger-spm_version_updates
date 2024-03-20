# frozen_string_literal: true

require "semantic"
require_relative "git"
require_relative "xcode"

module Danger
  # A Danger plugin for checking if there are versions upgrades available for SPM dependencies
  #
  # @example Check if MyApp's SPM dependencies are up to date
  #          spm_version_updates.check_for_updates("MyApp.xcodeproj")
  #
  # @see  hbmartin/danger-spm_version_updates
  # @tags swift, spm, swift package manager, xcode, xcodeproj, version, updates
  #
  class DangerSpmVersionUpdates < Plugin
    # Whether to check when dependencies are exact versions or commits, default false
    # @return   [Boolean]
    attr_accessor :check_when_exact

    # Whether to report versions above the maximum version range, default false
    # @return   [Boolean]
    attr_accessor :report_above_maximum

    # Whether to report pre-release versions, default false
    # @return   [Boolean]
    attr_accessor :report_pre_releases

    # A list of repository URLs for packages to ignore entirely
    # @return   [Array<String>]
    attr_accessor :ignore_repos

    # A method that you can call from your Dangerfile
    # @param   [String] xcodeproj_path
    #          The path to your Xcode project
    # @raise [XcodeprojPathMustBeSet] if the xcodeproj_path is blank
    # @return   [void]
    def check_for_updates(xcodeproj_path)
      remote_packages = Xcode.get_packages(xcodeproj_path)
      resolved_versions = Xcode.get_resolved_versions(xcodeproj_path)
      $stderr.puts("Found resolved versions for #{resolved_versions.size} packages")

      self.ignore_repos = self.ignore_repos&.map! { |repo| Git.trim_repo_url(repo) }

      remote_packages.each { |repository_url, requirement|
        next if self.ignore_repos&.include?(repository_url)

        name = Git.repo_name(repository_url)
        resolved_version = resolved_versions[repository_url]
        kind = requirement["kind"]

        if resolved_version.nil?
          $stderr.puts("Unable to locate the current version for #{name} (#{repository_url})")
          next
        end

        if kind == "branch"
          branch = requirement["branch"]
          last_commit = Git.branch_last_commit(repository_url, branch)
          warn("Newer commit available for #{name} (#{branch}): #{last_commit}") unless last_commit == resolved_version
          next
        end

        available_versions = Git.version_tags(repository_url)
        next if available_versions.first.to_s == resolved_version

        if kind == "exactVersion" && @check_when_exact
          warn_for_new_versions_exact(available_versions, name, resolved_version)
        elsif kind == "upToNextMajorVersion"
          warn_for_new_versions(:major, available_versions, name, resolved_version)
        elsif kind == "upToNextMinorVersion"
          warn_for_new_versions(:minor, available_versions, name, resolved_version)
        elsif kind == "versionRange"
          warn_for_new_versions_range(available_versions, name, requirement, resolved_version)
        end
      }
    end

    private

    def warn_for_new_versions_exact(available_versions, name, resolved_version)
      newest_version = available_versions.find { |version|
        report_pre_releases ? true : version.pre.nil?
      }
      warn(
        <<-TEXT
Newer version of #{name}: #{newest_version} (but this package is set to exact version #{resolved_version})
        TEXT
      ) unless newest_version.to_s == resolved_version
    end

    def warn_for_new_versions_range(available_versions, name, requirement, resolved_version)
      max_version = Semantic::Version.new(requirement["maximumVersion"])
      if available_versions.first < max_version
        warn("Newer version of #{name}: #{available_versions.first}")
      else
        newest_meeting_reqs = available_versions.find { |version|
          version < max_version && (report_pre_releases ? true : version.pre.nil?)
        }
        warn("Newer version of #{name}: #{newest_meeting_reqs}") unless newest_meeting_reqs.to_s == resolved_version
        warn(
          <<-TEXT
Newest version of #{name}: #{available_versions.first} (but this package is configured up to the next #{max_version} version)
          TEXT
        ) if report_above_maximum
      end
    end

    def warn_for_new_versions(major_or_minor, available_versions, name, resolved_version_string)
      resolved_version = Semantic::Version.new(resolved_version_string)
      newest_meeting_reqs = available_versions.find { |version|
        (version.send(major_or_minor) == resolved_version.send(major_or_minor)) && (report_pre_releases ? true : version.pre.nil?)
      }

      warn("Newer version of #{name}: #{newest_meeting_reqs}") unless newest_meeting_reqs == resolved_version
      return unless report_above_maximum

      newest_above_reqs = available_versions.find { |version|
        report_pre_releases ? true : version.pre.nil?
      }
      warn(
        <<-TEXT
Newest version of #{name}: #{available_versions.first} (but this package is configured up to the next #{major_or_minor} version)
        TEXT
      ) unless newest_above_reqs == newest_meeting_reqs || newest_meeting_reqs.to_s == resolved_version
    end
  end
end
