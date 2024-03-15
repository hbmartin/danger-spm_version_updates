# danger-spm_version_updates

[![CI](https://github.com/hbmartin/danger-spm_version_updates/actions/workflows/lint_and_test.yml/badge.svg)](https://github.com/hbmartin/danger-spm_version_updates/actions/workflows/lint_and_test.yml)
[![CodeFactor](https://www.codefactor.io/repository/github/hbmartin/danger-spm_version_updates/badge/main)](https://www.codefactor.io/repository/github/hbmartin/danger-spm_version_updates/overview/main)
[![Gem Version](https://img.shields.io/gem/v/danger-spm_version_updates?color=D86149)](https://rubygems.org/gems/danger-spm_version_updates)
[![codecov](https://codecov.io/gh/hbmartin/danger-spm_version_updates/graph/badge.svg?token=eXgUoWlvP7)](https://codecov.io/gh/hbmartin/danger-spm_version_updates)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A [Danger](https://danger.systems/ruby/) plugin to detect if there are any updates to your Swift Package Manager dependencies.

It's fast, lightweight, and does not require swift to be installed on the CI where it is run.

Note that version 0.1.0 is the last version to support Ruby 2.7

## Installation

    $ gem install danger-spm_version_updates

or add the following to your Gemfile:

```ruby
gem "danger-spm_version_updates"
```

## Usage

Just add this to your Dangerfile! Note that it is required to pass the path to your Xcode project.

```ruby
spm_version_updates.check_for_updates("Example.xcodeproj")
```

You can also configure custom behaviors:

```ruby
# Whether to check when dependencies are exact versions or commits, default false
spm_version_updates.check_when_exact = true

# Whether to report versions above the maximum version range, default false
spm_version_updates.report_above_maximum = true

# Whether to report pre-release versions, default false
spm_version_updates.report_pre_releases = true

# A list of repositories to ignore entirely, must exactly match the URL as configured in the Xcode project
spm_version_updates.ignore_repos = ["https://github.com/pointfreeco/swift-snapshot-testing"]
```

## Development

1. Clone this repo
2. Run `bundle install` to setup dependencies.
3. Run `bundle exec rake spec` to run the tests.
4. Use `bundle exec guard` to automatically have tests run as you make changes.
5. Make your changes.

## Authors

- [Harold Martin](https://www.linkedin.com/in/harold-martin-98526971/) - harold.martin at gmail

## Legal

Swift and the Swift logo are trademarks of Apple Inc.

Copyright (c) 2023 Harold Martin <harold.martin@gmail.com>

MIT License

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
