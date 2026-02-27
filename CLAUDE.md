# create-rails-app

## Build and Test Commands

- **Run all tests**: `bundle exec rake spec` or `bundle exec rspec`
- **Run single test file**: `bundle exec rspec spec/create_rails_app/wizard_spec.rb`
- **Run specific test**: `bundle exec rspec spec/create_rails_app/wizard_spec.rb:42`
- **Run linter**: `bundle exec rake rubocop` or `bundle exec rubocop`
- **Safe auto-fix lint issues**: `bundle exec rubocop -a`
- **Auto-fix ALL lint issues (potentially unsafe)**: `bundle exec rubocop -A`
- **Run both lint and tests**: `bundle exec rake` (default task)
- **Run tests with coverage**: `COVERAGE=1 bundle exec rspec`
- **Install dependencies**: `bin/setup`
- **Interactive console**: `bin/console`

## Architecture

Interactive CLI wizard for `rails new` — walks you through every option, remembers your choices, and saves reusable presets.

### Directory Layout

- `lib/` — gem source (shipped in the gem)
- `exe/` — CLI entrypoint
- `spec/` — RSpec tests

### Option Pipeline

Catalog (definition) → Matrix (version compatibility) → Wizard (UI) → CommandBuilder (CLI flags)

### Option Types

- `:flag` — opt-in (`--api`), nil when off
- `:enum` — value choice (`--database=postgresql`), false for "none"
- `:skip` — opt-out, true=include (no flag), false=exclude (`--skip-test`)

### Adding a New `rails new` Option

1. `lib/create_rails_app/options/catalog.rb` — add to DEFINITIONS + ORDER
2. `lib/create_rails_app/compatibility/matrix.rb` — add to COMMON_OPTIONS or version-specific hash
3. `lib/create_rails_app/wizard.rb` — add LABELS + HELP_TEXT (+ CHOICE_HELP for enums)
4. Specs auto-validate: "has LABELS for every ORDER key" and "has HELP_TEXT for every ORDER key"

## Code Style

- Ruby 3.2+ required
- Max line length: 120 characters
- RuboCop with rubocop-rspec extension
- RSpec with `expect` syntax only (no monkey patching)
- Frozen string literals in all Ruby files
- `.freeze` on all constant data structures

### Method Ordering (Stepdown Rule)

Follow the "Stepdown Rule" from Clean Code: methods should be ordered so that callers appear before callees. Code should read top-to-bottom like a newspaper article—high-level concepts first, implementation details below.

## Commit Message Convention

This project follows [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

Format: `<type>[optional scope]: <description>`

| Type | Description | Version bump |
|------|-------------|--------------|
| `feat` | New feature | MINOR |
| `fix` | Bug fix | PATCH |
| `docs` | Documentation only | — |
| `style` | Formatting, whitespace | — |
| `refactor` | Code change (no feature/fix) | — |
| `perf` | Performance improvement | — |
| `test` | Adding/fixing tests | — |
| `build` | Build system or dependencies | — |
| `ci` | CI configuration | — |
| `chore` | Maintenance tasks | — |

### Breaking Changes

Use `!` after type or add `BREAKING CHANGE:` footer. Breaking changes trigger a MAJOR version bump.

### Examples

```
feat: add Rails 8.2 support
fix: correct database prompt when Active Record is disabled
docs: update README with preset usage examples
refactor: extract shared prompt logic
chore: release v0.2.0
```

## Changelog Format

This project follows [Keep a Changelog v1.1.0](https://keepachangelog.com/en/1.1.0/).

Allowed categories in **required order**:

1. **Added** — new features
2. **Changed** — changes to existing functionality
3. **Deprecated** — soon-to-be removed features
4. **Removed** — removed features
5. **Fixed** — bug fixes
6. **Security** — vulnerability fixes

Rules:
- Categories must appear in the order listed above within each release section
- Each category must appear **at most once** per release section — always append to an existing category rather than creating a duplicate
- Do NOT use non-standard categories like "Updated", "Internal", or "Breaking changes"
- Breaking changes should be prefixed with **BREAKING:** within the relevant category (typically Changed or Removed)

## Community Standards

The repository includes GitHub community standards files:

- **`CODE_OF_CONDUCT.md`** — Contributor Covenant v2.1; enforcement contact: `leonid@svyatov.com`
- **`CONTRIBUTING.md`** — development setup, code style, commit conventions, and PR process
- **`SECURITY.md`** — vulnerability reporting via GitHub Security Advisories; v0.x supported

## Pre-Commit Checklist

Before committing changes, always verify these files are updated to accurately reflect the changes:

- **CLAUDE.md** — update this file if architecture or conventions change
- **README.md** — update usage examples, features list, and supported Rails versions
- **CHANGELOG.md** — add entry under `[Unreleased]` section (use only standard Keep a Changelog categories)
- **Marketing copy** — when adding major features, ensure descriptions stay unified: `create-rails-app.gemspec` (summary + description), `README.md` (tagline), GitHub repo description (via `gh repo edit --description`)

## Releasing a New Version

This project follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html):
- **MAJOR** — breaking changes (incompatible API changes)
- **MINOR** — new features (backwards-compatible)
- **PATCH** — bug fixes (backwards-compatible)

1. Update `lib/create_rails_app/version.rb` with the new version number
2. Update `CHANGELOG.md`: change `[Unreleased]` to `[X.Y.Z] - YYYY-MM-DD` and add new empty `[Unreleased]` section
3. Commit changes: `git commit -am "chore: release vX.Y.Z"`
4. Release: `bundle exec rake release` — builds the gem, creates and pushes the git tag, pushes to RubyGems.org
5. Create GitHub release at https://github.com/svyatov/create-rails-app/releases with notes from CHANGELOG
