# frozen_string_literal: true

require "semantic"
require "xcodeproj"

module Danger
  # @example Ensure people are well warned about merging on Mondays
  #
  #          my_plugin.warn_on_mondays
  #
  # @see  Harold Martin/danger-spm_version_updates
  # @tags swift, spm, swift package manager, xcode, xcodeproj, version, updates
  #
  class DangerSpmVersionUpdates < Plugin
    # The path to the xcodeproj file
    # @return   [String]
    attr_accessor :xcodeproj_path

    # Whether to check when dependencies are exact versions or commits, default false
    # @return   [Boolean]
    attr_accessor :check_when_exact

    # Whether to ignore version above the maximum version range, default true
    # @return   [Boolean]
    attr_accessor :quiet_above_maximum

    # A list of repositories to ignore entirely, must exactly match the URL as configured in the Xcode project
    # @return   [Array<String>]
    attr_accessor :ignore_repos

    def initialize(dangerfile)
      super(dangerfile)
      @check_when_exact = false
      @quiet_above_maximum = false
      @ignore_repos = []
    end

    # A method that you can call from your Dangerfile
    # @return   [Array<String>]
    def check_for_updates
      raise(XcodeprojPathMustBeSet) if xcodeproj_path.nil?

      project = Xcodeproj::Project.open(xcodeproj_path)
      remote_packages = filter_remote_packages(project)

      resolved_path = find_packages_resolved
      raise(CouldNotFindResolvedFile) unless File.exist?(resolved_path)

      resolved_versions = JSON.load_file!(resolved_path)["pins"]
        .to_h { |pin| [pin["location"], pin["state"]["version"] || pin["state"]["revision"]] }

      remote_packages.each { |repository_url, requirement|
        next if ignore_repos.include?(repository_url)

        name = repo_name(repository_url)
        resolved_version = resolved_versions[repository_url]
        kind = requirement["kind"]

        # kind can be major, minor, range, exact, branch, or commit

        if kind == "branch" && check_when_exact
          last_commit = git_branch_last_commit(repository_url, requirement["branch"])
          warn("Newer commit available for #{name}: #{last_commit}") unless last_commit == resolved_version
          next
        end

        available_versions = git_versions(repository_url)
        next if available_versions.first.to_s == resolved_version

        if kind == "exactVersion" && @check_when_exact
          warn(
            <<-TEXT
Newer version of #{name}: #{available_versions.first} (but this package is set to exact version #{resolved_version})
            TEXT
          )
        elsif kind == "upToNextMajorVersion"
          warn_for_new_versions(:major, available_versions, name, resolved_version)
        elsif kind == "upToNextMinorVersion"
          warn_for_new_versions(:minor, available_versions, name, resolved_version)
        elsif kind == "range"
          warn_for_new_versions_range(available_versions, name, requirement, resolved_version)
        end
      }
    end

    def repo_name(repo_url)
      match = repo_url.match(%r{([\w-]+/[\w-]+)(.git)?$})

      if match
        match[1] || match[0]
      else
        repo_url
      end
    end

    def filter_remote_packages(project)
      project.objects.select { |obj|
        obj.kind_of?(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference) &&
          obj.requirement["kind"] != "commit"
      }
        .to_h { |package| [package.repositoryURL, package.requirement] }
    end

    def find_packages_resolved
      if Dir.exist?(xcodeproj_path.sub("xcodeproj", "xcworkspace"))
        File.join(xcodeproj_path.sub("xcodeproj", "xcworkspace"), "xcshareddata", "swiftpm", "Package.resolved")
      else
        File.join(xcodeproj_path, "project.xcworkspace", "xcshareddata", "swiftpm", "Package.resolved")
      end
    end

    private

    def warn_for_new_versions_range(available_versions, name, requirement, resolved_version)
      max_version = Semantic::Version.new(requirement["maximumVersion"])
      if available_versions.first < max_version
        warn("Newer version of #{name}: #{available_versions.first}")
      else
        newest_meeting_reqs = available_versions.find { |version|
          version < max_version
        }
        warn("Newer version of #{name}: #{newest_meeting_reqs} ") unless newest_meeting_reqs.to_s == resolved_version
        warn(
          <<-TEXT
Newest version of #{name}: #{available_versions.first} (but this package is configured up to the next #{max_version} version)
          TEXT
        ) unless quiet_above_maximum
      end
    end

    def warn_for_new_versions(major_or_minor, available_versions, name, resolved_version_string)
      resolved_version = Semantic::Version.new(resolved_version_string)
      if available_versions.first.send(major_or_minor) == resolved_version.send(major_or_minor)
        warn("Newer version of #{name}: #{available_versions.first}")
      else
        newest_meeting_reqs = available_versions.find { |version|
          version.send(major_or_minor) == resolved_version.send(major_or_minor)
        }
        warn("Newer version of #{name}: #{newest_meeting_reqs}") unless newest_meeting_reqs == resolved_version
        warn(
          <<-TEXT
Newest version of #{name}: #{available_versions.first} (but this package is configured up to the next #{major_or_minor} version)
          TEXT
        ) unless quiet_above_maximum
      end
    end
  end

  def git_versions(repo_url)
    `git ls-remote -t #{repo_url}`
      .split("\n")
      .map { |line| line.split("/tags/").last }
      .filter_map { |line|
        begin
          Semantic::Version.new(line)
        rescue ArgumentError
          nil
        end
      }
      .sort
      .reverse
  end

  def git_branch_last_commit(repo_url, branch_name)
    `git ls-remote -h #{repo_url}`
      .split("\n")
      .find { |line| line.split("\trefs/heads/")[1] == branch_name }
      .split("\trefs/heads/")[0]
  end

  class XcodeprojPathMustBeSet < StandardError
  end

  class CouldNotFindResolvedFile < StandardError
  end
end
