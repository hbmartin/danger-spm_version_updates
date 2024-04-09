# frozen_string_literal: true

require "xcodeproj"

module Xcode
  # Find the configured SPM dependencies in the xcodeproj
  # @param   [String] xcodeproj_path
  #          The path of the Xcode project
  # @return [Hash<String, Hash>]
  def self.get_packages(xcodeproj_path)
    raise(XcodeprojPathMustBeSet) if xcodeproj_path.nil? || xcodeproj_path.empty?

    project = Xcodeproj::Project.open(xcodeproj_path)
    project.objects
      .select { |obj|
        obj.kind_of?(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
      }
      .to_h { |package|
        [Git.trim_repo_url(package.repositoryURL), package.requirement]
      }
  end

  # Extracts resolved versions from Package.resolved relative to an Xcode project
  # @param   [String] xcodeproj_path
  #          The path to your Xcode project
  # @raise [CouldNotFindResolvedFile] if no Package.resolved files were found
  # @return [Hash<String, String>]
  def self.get_resolved_versions(xcodeproj_path)
    resolved_paths = find_packages_resolved_file(xcodeproj_path)
    raise(CouldNotFindResolvedFile) if resolved_paths.empty?

    resolved_versions = resolved_paths.map { |resolved_path|
      contents = JSON.load_file!(resolved_path)
      pins = contents["pins"] || contents["object"]["pins"]
      pins.to_h { |pin|
        [
          Git.trim_repo_url(pin["location"] || pin["repositoryURL"]),
          pin["state"]["version"] || pin["state"]["revision"],
        ]
      }
    }
    resolved_versions.reduce(:merge!)
  end

  # Find the Packages.resolved file
  # @return [Array<String>]
  def self.find_packages_resolved_file(xcodeproj_path)
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

  private_class_method :find_packages_resolved_file

  class XcodeprojPathMustBeSet < StandardError
  end

  class CouldNotFindResolvedFile < StandardError
  end
end
