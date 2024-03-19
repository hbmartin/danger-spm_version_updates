# frozen_string_literal: true

require "semantic"
require "xcodeproj"

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

    # A list of repositories to ignore entirely, must exactly match the URL as configured in the Xcode project
    # @return   [Array<String>]
    attr_accessor :ignore_repos

    # A method that you can call from your Dangerfile
    # @param   [String] xcodeproj_path
    #          The path to your Xcode project
    # @return   [void]
    def check_for_updates(xcodeproj_path)
      remote_packages = get_remote_package(xcodeproj_path)
      resolved_versions = get_resolved_versions(xcodeproj_path)
      $stderr.puts("Found resolved versions for #{resolved_versions.size} packages")

      remote_packages.each { |repository_url, requirement|
        next if ignore_repos&.include?(repository_url)

        name = repo_name(repository_url)
        resolved_version = resolved_versions[repository_url]
        kind = requirement["kind"]

        if resolved_version.nil?
          $stderr.puts("Unable to locate the current version for #{name} (#{repository_url})")
          next
        end

        if kind == "branch"
          branch = requirement["branch"]
          last_commit = git_branch_last_commit(repository_url, branch)
          warn("Newer commit available for #{name} (#{branch}): #{last_commit}") unless last_commit == resolved_version
          next
        end

        available_versions = git_versions(repository_url)
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

    # Extracts remote packages from an Xcode project
    # @param   [String] xcodeproj_path
    #          The path to your Xcode project
    # @return [Hash<String, Hash>]
    def get_remote_package(xcodeproj_path)
      raise(XcodeprojPathMustBeSet) if xcodeproj_path.nil?

      filter_remote_packages(Xcodeproj::Project.open(xcodeproj_path))
    end

    # Extracts resolved versions from Package.resolved relative to an Xcode project
    # @param   [String] xcodeproj_path
    #          The path to your Xcode project
    # @return [Hash<String, String>]
    def get_resolved_versions(xcodeproj_path)
      resolved_paths = find_packages_resolved_file(xcodeproj_path)
      raise(CouldNotFindResolvedFile) if resolved_paths.empty?

      resolved_versions = resolved_paths.map { |resolved_path|
        JSON.load_file!(resolved_path)["pins"]
          .to_h { |pin|
            [pin["location"], pin["state"]["version"] || pin["state"]["revision"]]
          }
      }
      resolved_versions.reduce(:merge!)
    end

    # Extract a readable name for the repo given the url, generally org/repo
    # @return [String]
    def repo_name(repo_url)
      match = repo_url.match(%r{([\w-]+/[\w-]+)(.git)?$})

      if match
        match[1] || match[0]
      else
        repo_url
      end
    end

    # Find the configured SPM dependencies in the xcodeproj
    # @return [Hash<String, Hash>]
    def filter_remote_packages(project)
      project.objects.select { |obj|
        obj.kind_of?(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference) &&
          obj.requirement["kind"] != "commit"
      }
        .to_h { |package| [package.repositoryURL, package.requirement] }
    end

    # Find the Packages.resolved file
    # @return [Array<String>]
    def find_packages_resolved_file(xcodeproj_path)
      locations = []
      # First check the workspace for a resolved file
      workspace = xcodeproj_path.sub("xcodeproj", "xcworkspace")
      if Dir.exist?(workspace)
        path = File.join(workspace, "xcshareddata", "swiftpm", "Package.resolved")
        locations << path if File.exist?(path)
      end

      # Then check the project for a resolved file
      path = File.join(xcodeproj_path, "project.xcworkspace", "xcshareddata", "swiftpm", "Package.resolved")
      locations << path if File.exist?(path)

      $stderr.puts("Searching for resolved packages in: #{locations}")
      locations
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

    # Call git to list tags
    # @param   [String] repo_url
    #          The URL of the dependency's repository
    # @return [Array<Semantic::Version>]
    def git_versions(repo_url)
      versions = `git ls-remote -t #{repo_url}`
        .split("\n")
        .map { |line| line.split("/tags/").last }
        .filter_map { |line|
          begin
            Semantic::Version.new(line)
          rescue ArgumentError
            nil
          end
        }
      versions.sort!
      versions.reverse!
      versions
    end

    # Calkl git to find the last commit on a branch
    # @param   [String] repo_url
    #          The URL of the dependency's repository
    # @param   [String] branch_name
    #          The name of the branch on which to find the last commit
    # @return [String]
    def git_branch_last_commit(repo_url, branch_name)
      `git ls-remote -h #{repo_url}`
        .split("\n")
        .find { |line| line.split("\trefs/heads/")[1] == branch_name }
        .split("\trefs/heads/")[0]
    end
  end

  class XcodeprojPathMustBeSet < StandardError
  end

  class CouldNotFindResolvedFile < StandardError
  end
end
