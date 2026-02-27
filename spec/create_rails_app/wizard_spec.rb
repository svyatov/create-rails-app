# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/fake_prompter'

RSpec.describe CreateRailsApp::Wizard do
  let(:full_entry) { CreateRailsApp::Compatibility::Matrix.for('8.1.0') }

  def build_entry(supported_options)
    CreateRailsApp::Compatibility::Matrix::Entry.new(
      requirement: Gem::Requirement.new('>= 0'),
      supported_options: supported_options
    )
  end

  it 'has LABELS for every Catalog::ORDER key' do
    expect(described_class::LABELS.keys).to include(*CreateRailsApp::Options::Catalog::ORDER)
  end

  it 'has HELP_TEXT for every Catalog::ORDER key' do
    expect(described_class::HELP_TEXT.keys).to include(*CreateRailsApp::Options::Catalog::ORDER)
  end

  it 'has CHOICE_HELP entries for all enum values that have hints' do
    CreateRailsApp::Options::Catalog::DEFINITIONS.each do |key, definition|
      next unless definition[:type] == :enum
      next unless described_class::CHOICE_HELP.key?(key)

      definition[:values].each do |value|
        expect(described_class::CHOICE_HELP[key].key?(value))
          .to(be(true), "CHOICE_HELP[:#{key}] missing hint for '#{value}'")
      end
    end
  end

  it 'completes a straight-through run' do
    prompter = FakePrompter.new(choices: [])

    result = described_class.new(
      compatibility_entry: full_entry,
      defaults: {},
      prompter: prompter
    ).run

    expect(result).not_to have_key(:api)
  end

  it 'records skip false when user chooses yes' do
    entry = build_entry(hotwire: nil, jbuilder: nil)
    prompter = FakePrompter.new(choices: %w[yes no])

    result = described_class.new(compatibility_entry: entry, defaults: {}, prompter: prompter).run

    expect(result[:hotwire]).to be(false)
    expect(result[:jbuilder]).to be(true)
  end

  it 'records true for flag when user chooses yes' do
    entry = build_entry(api: nil)
    prompter = FakePrompter.new(choices: %w[yes])

    result = described_class.new(compatibility_entry: entry, defaults: {}, prompter: prompter).run

    expect(result[:api]).to be(true)
  end

  it 'records enum value when user picks one' do
    entry = build_entry(database: %w[sqlite3 postgresql mysql trilogy])
    prompter = FakePrompter.new(choices: %w[postgresql])

    result = described_class.new(compatibility_entry: entry, defaults: {}, prompter: prompter).run

    expect(result[:database]).to eq('postgresql')
  end

  it 'records false for enum none' do
    entry = build_entry(javascript: %w[importmap bun])
    prompter = FakePrompter.new(choices: %w[none])

    result = described_class.new(compatibility_entry: entry, defaults: {}, prompter: prompter).run

    expect(result[:javascript]).to be(false)
  end

  it 'supports going back to previous steps' do
    entry = build_entry(hotwire: nil, jbuilder: nil, docker: nil)
    prompter = FakePrompter.new(
      choices: [
        'no',                                   # skip hotwire? no
        'yes',                                  # skip jbuilder? yes
        CreateRailsApp::Wizard::BACK,           # go back to jbuilder
        'no',                                   # skip jbuilder? no
        'no'                                    # skip docker? no
      ]
    )

    result = described_class.new(compatibility_entry: entry, defaults: {}, prompter: prompter).run

    expect(result[:hotwire]).to be(true)
    expect(result[:jbuilder]).to be(true)
    expect(result[:docker]).to be(true)
  end

  it 'stays at index 0 when going back on first step' do
    entry = build_entry(api: nil)
    prompter = FakePrompter.new(choices: [CreateRailsApp::Wizard::BACK, 'yes'])

    result = described_class.new(compatibility_entry: entry, defaults: {}, prompter: prompter).run

    expect(result[:api]).to be(true)
  end

  it 'does not offer "none" for database' do
    entry = build_entry(active_record: nil, database: %w[sqlite3 postgresql mysql trilogy])
    prompter = FakePrompter.new(choices: %w[no sqlite3])

    described_class.new(compatibility_entry: entry, defaults: {}, prompter: prompter).run

    db_options = prompter.seen_options[1]
    none_option = db_options&.find { |opt| opt.match?(/\bnone\b/) }
    expect(none_option).to be_nil
  end

  it 'auto-skips database when active_record is false' do
    entry = build_entry(active_record: nil, database: %w[sqlite3 postgresql mysql trilogy])
    prompter = FakePrompter.new(choices: %w[yes])

    result = described_class.new(compatibility_entry: entry, defaults: {}, prompter: prompter).run

    expect(prompter.seen_questions.length).to eq(1)
    expect(result[:active_record]).to be(false)
    expect(result).not_to have_key(:database)
  end

  it 'auto-skips javascript, css, asset_pipeline, hotwire, jbuilder, action_text when api is true' do
    entry = build_entry(
      api: nil, javascript: %w[importmap bun], css: %w[tailwind bootstrap],
      asset_pipeline: nil, hotwire: nil, jbuilder: nil, action_text: nil
    )
    prompter = FakePrompter.new(choices: %w[yes])

    result = described_class.new(compatibility_entry: entry, defaults: {}, prompter: prompter).run

    expect(prompter.seen_questions.length).to eq(1)
    expect(result[:api]).to be(true)
    expect(result).not_to have_key(:asset_pipeline)
  end

  it 'auto-skips active_storage, action_mailbox, action_text when active_record is false' do
    entry = build_entry(
      active_record: nil, database: %w[sqlite3 postgresql],
      action_mailbox: nil, active_storage: nil, action_text: nil
    )
    prompter = FakePrompter.new(choices: %w[yes])

    result = described_class.new(compatibility_entry: entry, defaults: {}, prompter: prompter).run

    expect(prompter.seen_questions.length).to eq(1)
    expect(result[:active_record]).to be(false)
    expect(result).not_to have_key(:database)
    expect(result).not_to have_key(:action_mailbox)
    expect(result).not_to have_key(:active_storage)
    expect(result).not_to have_key(:action_text)
  end

  it 'auto-skips system_test when test is none' do
    entry = build_entry(test: %w[minitest], system_test: nil)
    prompter = FakePrompter.new(choices: %w[none])

    result = described_class.new(compatibility_entry: entry, defaults: {}, prompter: prompter).run

    expect(prompter.seen_questions.length).to eq(1)
    expect(result[:test]).to be(false)
  end

  it 'sanitizes defaults to only supported options' do
    entry = build_entry(api: nil)
    prompter = FakePrompter.new(choices: %w[yes])

    result = described_class.new(
      compatibility_entry: entry,
      defaults: { api: true, kamal: false, bogus: 'value' },
      prompter: prompter
    ).run

    expect(result).to eq(api: true)
  end

  it 'uses defaults from last-used when available' do
    entry = build_entry(hotwire: nil)
    prompter = FakePrompter.new(choices: [])

    result = described_class.new(
      compatibility_entry: entry,
      defaults: { 'hotwire' => false },
      prompter: prompter
    ).run

    expect(result[:hotwire]).to be(false)
  end

  it 'shows step counter and help text in questions' do
    entry = build_entry(api: nil)
    prompter = FakePrompter.new(choices: [])

    described_class.new(compatibility_entry: entry, defaults: {}, prompter: prompter).run

    question = prompter.seen_questions.first
    expect(question).to include('API-only mode')
    expect(question).to include('API backends')
  end

  it 'shows choice hints for enum options' do
    entry = build_entry(database: %w[sqlite3 postgresql mysql trilogy])
    prompter = FakePrompter.new(choices: [])

    described_class.new(compatibility_entry: entry, defaults: {}, prompter: prompter).run

    flattened = prompter.seen_options.flatten
    expect(flattened.any? { |opt| opt.include?('popular for production') }).to be(true)
  end

  it 'labels Rails default, not last-used, as (default)' do
    entry = build_entry(database: %w[sqlite3 postgresql mysql trilogy])
    prompter = FakePrompter.new(choices: [])

    described_class.new(
      compatibility_entry: entry,
      defaults: { database: 'postgresql' },
      prompter: prompter
    ).run

    flattened = prompter.seen_options.flatten
    expect(flattened.first).to start_with('sqlite3')
    expect(flattened.first).to include('(default)')
    pg_option = flattened.find { |opt| opt.start_with?('postgresql') }
    expect(pg_option).not_to include('(default)')
  end

  it 'clears stale downstream values when back-navigation changes a parent option' do
    entry = build_entry(
      api: nil, javascript: %w[importmap bun], css: %w[tailwind bootstrap], hotwire: nil
    )
    prompter = FakePrompter.new(
      choices: [
        'no',                                   # api = no
        'importmap',                            # javascript = importmap
        'tailwind',                             # css = tailwind
        CreateRailsApp::Wizard::BACK,           # back from hotwire → css
        CreateRailsApp::Wizard::BACK,           # back from css → javascript
        CreateRailsApp::Wizard::BACK,           # back from javascript → api
        'yes'                                   # api = yes (skips rest)
      ]
    )

    result = described_class.new(compatibility_entry: entry, defaults: {}, prompter: prompter).run

    expect(result[:api]).to be(true)
    expect(result).not_to have_key(:javascript)
    expect(result).not_to have_key(:css)
    expect(result).not_to have_key(:hotwire)
  end

  it 'preserves database choice after toggling active_record back to true' do
    entry = build_entry(active_record: nil, database: %w[sqlite3 postgresql mysql trilogy], hotwire: nil)
    prompter = FakePrompter.new(
      choices: [
        'no',                                 # skip active_record? no
        'postgresql',                         # database = postgresql
        CreateRailsApp::Wizard::BACK,         # back from hotwire → database
        CreateRailsApp::Wizard::BACK,         # back from database → active_record
        'yes',                                # skip active_record? yes (database auto-skipped)
        CreateRailsApp::Wizard::BACK,         # back from hotwire → active_record (database skipped)
        'no',                                 # skip active_record? no (database restored from stash)
        'no'                                  # skip hotwire? no
      ]
    )

    result = described_class.new(compatibility_entry: entry, defaults: {}, prompter: prompter).run

    expect(result[:active_record]).to be(true)
    expect(result[:database]).to eq('postgresql')
    expect(result[:hotwire]).to be(true)
  end

  it 'presents asset_pipeline as enum for Rails 7.2' do
    entry = CreateRailsApp::Compatibility::Matrix.for('7.2.0')
    keys = CreateRailsApp::Options::Catalog::ORDER.select { |k| entry.supports_option?(k) }
    prompter = FakePrompter.new(choices: Array.new(keys.length))

    described_class.new(compatibility_entry: entry, defaults: {}, prompter: prompter).run

    ap_index = keys.index(:asset_pipeline)
    ap_options = prompter.seen_options[ap_index]
    expect(ap_options.any? { |opt| opt.include?('propshaft') }).to be(true)
    expect(ap_options.any? { |opt| opt.include?('sprockets') }).to be(true)
  end

  it 'presents asset_pipeline as yes/no skip for Rails 8.0+' do
    entry = build_entry(asset_pipeline: nil)
    prompter = FakePrompter.new(choices: %w[yes])

    result = described_class.new(compatibility_entry: entry, defaults: {}, prompter: prompter).run

    expect(result[:asset_pipeline]).to be(false)
    ap_options = prompter.seen_options.first
    expect(ap_options.any? { |opt| opt.include?('no') }).to be(true)
    expect(ap_options.any? { |opt| opt.include?('yes') }).to be(true)
  end

  it 'presents bundler_audit step for Rails 8.1' do
    entry = CreateRailsApp::Compatibility::Matrix.for('8.1.0')
    keys = CreateRailsApp::Options::Catalog::ORDER.select { |k| entry.supports_option?(k) }
    expect(keys).to include(:bundler_audit)

    prompter = FakePrompter.new(choices: Array.new(keys.length))

    described_class.new(compatibility_entry: entry, defaults: {}, prompter: prompter).run

    ba_index = keys.index(:bundler_audit)
    question = prompter.seen_questions[ba_index]
    expect(question).to include('Bundler Audit')
  end

  it 'does not present bundler_audit step for Rails 8.0' do
    entry = CreateRailsApp::Compatibility::Matrix.for('8.0.0')
    keys = CreateRailsApp::Options::Catalog::ORDER.select { |k| entry.supports_option?(k) }
    expect(keys).not_to include(:bundler_audit)
  end

  it 'back-navigates past auto-skipped steps' do
    entry = build_entry(
      api: nil, javascript: %w[importmap bun], css: %w[tailwind],
      hotwire: nil, jbuilder: nil, action_text: nil, test: %w[minitest]
    )
    prompter = FakePrompter.new(
      choices: [
        'yes',                                  # api = true (skips js, css, hotwire, jbuilder, action_text)
        CreateRailsApp::Wizard::BACK,           # back from test → lands on api
        'no',                                   # api = no
        'importmap',                            # javascript
        'tailwind',                             # css
        'no',                                   # skip hotwire? no
        'no',                                   # skip jbuilder? no
        'no',                                   # skip action_text? no
        'minitest'                              # test
      ]
    )

    result = described_class.new(compatibility_entry: entry, defaults: {}, prompter: prompter).run

    expect(result).not_to have_key(:api)
    expect(result[:javascript]).to eq('importmap')
  end
end
