# create-rails-app [![Gem Version](https://img.shields.io/gem/v/create-rails-app)](https://rubygems.org/gems/create-rails-app) [![Codecov](https://img.shields.io/codecov/c/github/svyatov/create-rails-app)](https://app.codecov.io/gh/svyatov/create-rails-app) [![CI](https://github.com/svyatov/create-rails-app/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/svyatov/create-rails-app/actions?query=workflow%3ACI)

> Interactive CLI wizard for `rails new` — walks you through every option, remembers your choices, and saves reusable presets.

## Table of Contents

- [Supported Ruby Versions](#supported-ruby-versions)
- [Installation](#installation)
- [Features](#features)
- [Usage](#usage)
- [Configuration](#configuration)
- [Supported Rails Versions](#supported-rails-versions)
- [Development](#development)
- [Contributing](#contributing)
- [Changelog](#changelog)
- [Versioning](#versioning)
- [License](#license)

## Supported Ruby Versions

Ruby 3.2+ is required.

## Installation

```bash
gem install create-rails-app
```

## Features

- Interactive step-by-step wizard for all `rails new` options
- Supports Rails 7.2+ with version-aware option filtering
- Remembers last-used choices and saves reusable presets
- Back navigation (<kbd>Ctrl+B</kbd>) to change previous answers
- Dry-run mode to preview the generated command
- Smart skip rules (e.g., skips database prompt if Active Record is disabled)
- Color-coded terminal UI

## Usage

Start the wizard:

```bash
create-rails-app
```

With an app name:

```bash
create-rails-app myapp
```

Preview the generated command without running it:

```bash
create-rails-app --dry-run
```

Use a saved preset:

```bash
create-rails-app --preset api
```

List available presets:

```bash
create-rails-app --list-presets
```

## Configuration

Presets and last-used choices are stored in `~/.config/create-rails-app/config.yml` (follows the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/latest/)).

## Supported Rails Versions

| Version | Supported          |
|---------|--------------------|
| 8.1     | :white_check_mark: |
| 8.0     | :white_check_mark: |
| 7.2     | :white_check_mark: |

## Development

After checking out the repo, run `bin/setup` to install dependencies.
Then, run `bundle exec rake` to run the tests. You can also run `bin/console`
for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

Sibling project: [create-ruby-gem](https://github.com/svyatov/create-ruby-gem) — the same idea for `bundle gem`.

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/svyatov/create-rails-app). See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, code style, and PR guidelines.

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes, following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.

## Versioning

This project follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html)

## License

The gem is available as open source under the terms of
the [MIT License](LICENSE.txt).
