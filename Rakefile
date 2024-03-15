# frozen_string_literal: true

require "bundler/gem_tasks"
require "reek/rake/task"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:specs)

task default: :specs

task :spec do
  Rake::Task["specs"].invoke
  Rake::Task["rubocop"].invoke
  Rake::Task["spec_docs"].invoke
end

desc "Run RuboCop on the lib/specs directory"
RuboCop::RakeTask.new(:rubocop) { |task|
  task.requires << "rubocop-rspec"
  task.requires << "rubocop-rake"
  task.requires << "rubocop-performance"
  task.patterns = ["lib/**/*.rb", "spec/**/*.rb"]
}

desc "Run Reek on the lib/specs directory"
Reek::Rake::Task.new(:reek) { |task|
  task.source_files = FileList["lib/**/*.rb", "spec/**/*.rb"]
}

desc "Ensure that the plugin passes `danger plugins lint`"
task :spec_docs do
  sh "bundle exec danger plugins lint"
end
