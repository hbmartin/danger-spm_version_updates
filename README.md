# danger-spm_version_updates

[![CI](https://github.com/hbmartin/danger-spm_version_updates/actions/workflows/lint_and_test.yml/badge.svg)](https://github.com/hbmartin/danger-spm_version_updates/actions/workflows/lint_and_test.yml)
[![CodeFactor](https://www.codefactor.io/repository/github/hbmartin/danger-spm_version_updates/badge/main)](https://www.codefactor.io/repository/github/hbmartin/danger-spm_version_updates/overview/main)
[![Gem Version](https://badge.fury.io/rb/danger-spm_version_updates.svg)](https://badge.fury.io/rb/danger-spm_version_updates)


This is a Danger plugin to detect if there are any updates to your Swift Package Manager dependencies.

It is lightweight and does not require swift to be installed on the CI where it is run. 


## Installation

    $ gem install danger-spm_version_updates

or add the following to your Gemfile:


```ruby
gem "danger-spm_version_updates"
```


## Usage

Just add this to your Dangerfile! Note that it is required to configure the path to your Xcode project.

```ruby
spm_version_updates.xcodeproj_path = ".../Example.xcodeproj"
spm_version_updates.check_for_updates
```

You can also configure custom behaviors:

```ruby
# Whether to check when dependencies are exact versions or commits, default false
spm_version_updates.check_when_exact = true
# Whether to ignore version above the maximum version range, default true
spm_version_updates.quiet_above_maximum = false
# A list of repositories to ignore entirely, must exactly match the URL as configured in the Xcode project
spm_version_updates.ignore_repositories = ["https://github.com/pointfreeco/swift-snapshot-testing"]
```


## Development

1. Clone this repo
2. Run `bundle install` to setup dependencies.
3. Run `bundle exec rake spec` to run the tests.
4. Use `bundle exec guard` to automatically have tests run as you make changes.
5. Make your changes.


## Authors

* [Harold Martin](https://www.linkedin.com/in/harold-martin-98526971/) - harold.martin at gmail
