# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "spm_version_updates/gem_version"

Gem::Specification.new do |spec|
  spec.name          = "danger-spm_version_updates"
  spec.version       = SpmVersionUpdates::VERSION
  spec.authors       = ["Harold Martin"]
  spec.email         = ["harold.martin@gmail.com"]
  spec.description   = "A Danger plugin to detect if there are any updates to your Swift Package Manager dependencies."
  spec.summary       = "A Danger plugin to detect if there are any updates to your Swift Package Manager dependencies."
  spec.homepage      = "https://github.com/hbmartin/danger-spm_version_updates"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files         = Dir['lib/*'] + Dir['lib/**/*'] + Dir['*']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.add_runtime_dependency("danger-plugin-api", "~> 1.0")
  spec.add_runtime_dependency("semantic", "~> 1.6")
  spec.add_runtime_dependency("xcodeproj", "~> 1.24")

  # General ruby development
  spec.add_development_dependency("bundler", "~> 2.0")
  spec.add_development_dependency("rake", "~> 13.2")

  # Testing support
  spec.add_development_dependency("rspec", "~> 3.9")
  spec.add_development_dependency("simplecov", "~> 0.22")
  spec.add_development_dependency("simplecov-cobertura", "~> 2.1")

  # Linting code and docs
  spec.add_development_dependency("reek")
  spec.add_development_dependency("rubocop", "~> 1.63")
  spec.add_development_dependency("rubocop-performance")
  spec.add_development_dependency("rubocop-rake")
  spec.add_development_dependency("rubocop-rspec")
  spec.add_development_dependency("yard", "~> 0.9.36")

  # Makes testing easy via `bundle exec guard`
  spec.add_development_dependency("guard", "~> 2.16")
  spec.add_development_dependency("guard-rspec", "~> 4.7")
  spec.add_development_dependency("guard-rubocop", "~> 1.2")

  # If you want to work on older builds of ruby
  spec.add_development_dependency("listen", "3.0.7")

  # This gives you the chance to run a REPL inside your tests
  # via:
  #
  #    require 'pry'
  #    binding.pry
  #
  # This will stop test execution and let you inspect the results
  spec.add_development_dependency("pry")
end
