# create-rails-app

## Development

- `bundle exec rspec` — run all tests (~0.7s, coverage report in /coverage)
- Ruby gem, no build step needed

## Architecture

Option pipeline: Catalog (definition) → Matrix (version compatibility) → Wizard (UI) → CommandBuilder (CLI flags)

### Option types
- `:flag` — opt-in (`--api`), nil when off
- `:enum` — value choice (`--database=postgresql`), false for "none"
- `:skip` — opt-out, true=include (no flag), false=exclude (`--skip-test`)

### Adding a new `rails new` option
1. `lib/create_rails_app/options/catalog.rb` — add to DEFINITIONS + ORDER
2. `lib/create_rails_app/compatibility/matrix.rb` — add to COMMON_OPTIONS or version-specific hash
3. `lib/create_rails_app/wizard.rb` — add LABELS + HELP_TEXT (+ CHOICE_HELP for enums)
4. Specs auto-validate: "has LABELS for every ORDER key" and "has HELP_TEXT for every ORDER key"

## Code Style

- Conventional Commits: `type(scope): description`
- Frozen string literals in all Ruby files
- `.freeze` on all constant data structures
