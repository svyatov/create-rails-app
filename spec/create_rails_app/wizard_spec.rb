# frozen_string_literal: true

require 'spec_helper'

class WizardFakePrompter
  attr_reader :seen_options, :seen_questions

  def initialize(choices:, texts: [])
    @choices = choices
    @texts = texts
    @seen_options = []
    @seen_questions = []
  end

  def choose(question, options:, default: nil)
    @seen_questions << question
    @seen_options << options
    value = @choices.shift || default
    return CreateRailsApp::Wizard::BACK if value == CreateRailsApp::Wizard::BACK

    value ||= options.first
    unless options.include?(value)
      labeled_value = options.find do |option|
        normalized = strip_markup(option).gsub(/\n+/, '').sub(/ \(default\)\z/, '').sub(/ - .+\z/, '')
        normalized == value
      end
      value = labeled_value unless labeled_value.nil?
    end
    raise "invalid choice #{value.inspect}" unless options.include?(value)

    value
  end

  def text(_question, default: nil, allow_empty: true)
    value = @texts.shift
    value = default if value.nil?
    value = '' if value.nil? && allow_empty
    value
  end

  private

  def strip_markup(value)
    value.gsub(/\{\{[^:}]+:/, '').gsub('}}', '')
  end
end

RSpec.describe CreateRailsApp::Wizard do
  let(:full_entry) { CreateRailsApp::Compatibility::Matrix.for('8.1.0') }

  it 'completes a straight-through run' do
    # All defaults (include for skips, first choice for enums, no for flags)
    prompter = WizardFakePrompter.new(choices: [])

    result = described_class.new(
      compatibility_entry: full_entry,
      defaults: {},
      prompter: prompter
    ).run

    # With all defaults, skip types default to 'include' (true) and flag defaults to 'no' (nil)
    expect(result).not_to have_key(:api)
  end

  it 'records skip false when user chooses skip' do
    entry = CreateRailsApp::Compatibility::Matrix::Entry.new(
      requirement: Gem::Requirement.new('>= 0'),
      supported_options: { hotwire: nil, jbuilder: nil }
    )
    prompter = WizardFakePrompter.new(choices: %w[skip include])

    result = described_class.new(
      compatibility_entry: entry,
      defaults: {},
      prompter: prompter
    ).run

    expect(result[:hotwire]).to be(false)
    expect(result[:jbuilder]).to be(true)
  end

  it 'records true for flag when user chooses yes' do
    entry = CreateRailsApp::Compatibility::Matrix::Entry.new(
      requirement: Gem::Requirement.new('>= 0'),
      supported_options: { api: nil }
    )
    prompter = WizardFakePrompter.new(choices: %w[yes])

    result = described_class.new(
      compatibility_entry: entry,
      defaults: {},
      prompter: prompter
    ).run

    expect(result[:api]).to be(true)
  end

  it 'records enum value when user picks one' do
    entry = CreateRailsApp::Compatibility::Matrix::Entry.new(
      requirement: Gem::Requirement.new('>= 0'),
      supported_options: { database: %w[sqlite3 postgresql mysql trilogy] }
    )
    prompter = WizardFakePrompter.new(choices: %w[postgresql])

    result = described_class.new(
      compatibility_entry: entry,
      defaults: {},
      prompter: prompter
    ).run

    expect(result[:database]).to eq('postgresql')
  end

  it 'records false for enum none' do
    entry = CreateRailsApp::Compatibility::Matrix::Entry.new(
      requirement: Gem::Requirement.new('>= 0'),
      supported_options: { javascript: %w[importmap bun] }
    )
    # javascript definition has none: '--skip-javascript'
    prompter = WizardFakePrompter.new(choices: %w[none])

    result = described_class.new(
      compatibility_entry: entry,
      defaults: {},
      prompter: prompter
    ).run

    expect(result[:javascript]).to be(false)
  end

  it 'supports going back to previous steps' do
    entry = CreateRailsApp::Compatibility::Matrix::Entry.new(
      requirement: Gem::Requirement.new('>= 0'),
      supported_options: { hotwire: nil, jbuilder: nil, docker: nil }
    )
    prompter = WizardFakePrompter.new(
      choices: [
        'include',                              # hotwire = include
        'skip',                                 # jbuilder = skip
        CreateRailsApp::Wizard::BACK,           # go back to jbuilder
        'include',                              # jbuilder = include
        'include'                               # docker = include
      ]
    )

    result = described_class.new(
      compatibility_entry: entry,
      defaults: {},
      prompter: prompter
    ).run

    expect(result[:hotwire]).to be(true)
    expect(result[:jbuilder]).to be(true)
    expect(result[:docker]).to be(true)
  end

  it 'stays at index 0 when going back on first step' do
    entry = CreateRailsApp::Compatibility::Matrix::Entry.new(
      requirement: Gem::Requirement.new('>= 0'),
      supported_options: { api: nil }
    )
    prompter = WizardFakePrompter.new(
      choices: [CreateRailsApp::Wizard::BACK, 'yes']
    )

    result = described_class.new(
      compatibility_entry: entry,
      defaults: {},
      prompter: prompter
    ).run

    expect(result[:api]).to be(true)
  end

  it 'auto-skips database when active_record is false' do
    entry = CreateRailsApp::Compatibility::Matrix::Entry.new(
      requirement: Gem::Requirement.new('>= 0'),
      supported_options: {
        active_record: nil,
        database: %w[sqlite3 postgresql mysql trilogy]
      }
    )
    prompter = WizardFakePrompter.new(choices: %w[skip])

    result = described_class.new(
      compatibility_entry: entry,
      defaults: {},
      prompter: prompter
    ).run

    # Only one question asked (active_record), database was auto-skipped
    expect(prompter.seen_questions.length).to eq(1)
    expect(result[:active_record]).to be(false)
    expect(result).not_to have_key(:database)
  end

  it 'auto-skips javascript, css, hotwire, jbuilder when api is true' do
    entry = CreateRailsApp::Compatibility::Matrix::Entry.new(
      requirement: Gem::Requirement.new('>= 0'),
      supported_options: {
        api: nil,
        javascript: %w[importmap bun],
        css: %w[tailwind bootstrap],
        hotwire: nil,
        jbuilder: nil,
        action_text: nil
      }
    )
    prompter = WizardFakePrompter.new(choices: %w[yes])

    result = described_class.new(
      compatibility_entry: entry,
      defaults: {},
      prompter: prompter
    ).run

    # Only one question asked (api)
    expect(prompter.seen_questions.length).to eq(1)
    expect(result[:api]).to be(true)
  end

  it 'auto-skips system_test when test is false' do
    entry = CreateRailsApp::Compatibility::Matrix::Entry.new(
      requirement: Gem::Requirement.new('>= 0'),
      supported_options: {
        test: nil,
        system_test: nil
      }
    )
    prompter = WizardFakePrompter.new(choices: %w[skip])

    result = described_class.new(
      compatibility_entry: entry,
      defaults: {},
      prompter: prompter
    ).run

    expect(prompter.seen_questions.length).to eq(1)
    expect(result[:test]).to be(false)
  end

  it 'sanitizes defaults to only supported options' do
    entry = CreateRailsApp::Compatibility::Matrix::Entry.new(
      requirement: Gem::Requirement.new('>= 0'),
      supported_options: { api: nil }
    )
    prompter = WizardFakePrompter.new(choices: %w[yes])

    result = described_class.new(
      compatibility_entry: entry,
      defaults: { api: true, kamal: false, bogus: 'value' },
      prompter: prompter
    ).run

    expect(result).to eq(api: true)
  end

  it 'uses defaults from last-used when available' do
    entry = CreateRailsApp::Compatibility::Matrix::Entry.new(
      requirement: Gem::Requirement.new('>= 0'),
      supported_options: { hotwire: nil }
    )
    prompter = WizardFakePrompter.new(choices: [])

    result = described_class.new(
      compatibility_entry: entry,
      defaults: { 'hotwire' => false },
      prompter: prompter
    ).run

    # Default is 'skip' because hotwire=false, so the default choice is picked
    expect(result[:hotwire]).to be(false)
  end

  it 'shows step counter and help text in questions' do
    entry = CreateRailsApp::Compatibility::Matrix::Entry.new(
      requirement: Gem::Requirement.new('>= 0'),
      supported_options: { api: nil }
    )
    prompter = WizardFakePrompter.new(choices: [])

    described_class.new(
      compatibility_entry: entry,
      defaults: {},
      prompter: prompter
    ).run

    question = prompter.seen_questions.first
    expect(question).to include('API-only mode')
    expect(question).to include('API backends')
  end

  it 'shows choice hints for enum options' do
    entry = CreateRailsApp::Compatibility::Matrix::Entry.new(
      requirement: Gem::Requirement.new('>= 0'),
      supported_options: { database: %w[sqlite3 postgresql mysql trilogy] }
    )
    prompter = WizardFakePrompter.new(choices: [])

    described_class.new(
      compatibility_entry: entry,
      defaults: {},
      prompter: prompter
    ).run

    flattened = prompter.seen_options.flatten
    expect(flattened.any? { |opt| opt.include?('popular for production') }).to be(true)
  end

  it 'labels Rails default, not last-used, as (default)' do
    entry = CreateRailsApp::Compatibility::Matrix::Entry.new(
      requirement: Gem::Requirement.new('>= 0'),
      supported_options: { database: %w[sqlite3 postgresql mysql trilogy] }
    )
    prompter = WizardFakePrompter.new(choices: [])

    described_class.new(
      compatibility_entry: entry,
      defaults: { database: 'postgresql' },
      prompter: prompter
    ).run

    flattened = prompter.seen_options.flatten
    # sqlite3 is the Rails default — first in order and labeled "(default)"
    expect(flattened.first).to start_with('sqlite3')
    expect(flattened.first).to include('(default)')
    # postgresql is the last-used pick — NOT labeled "(default)"
    pg_option = flattened.find { |opt| opt.start_with?('postgresql') }
    expect(pg_option).not_to include('(default)')
  end

  it 'clears stale downstream values when back-navigation changes a parent option' do
    entry = CreateRailsApp::Compatibility::Matrix::Entry.new(
      requirement: Gem::Requirement.new('>= 0'),
      supported_options: {
        api: nil,
        javascript: %w[importmap bun],
        css: %w[tailwind bootstrap],
        hotwire: nil
      }
    )
    prompter = WizardFakePrompter.new(
      choices: [
        'no',                                   # api = no (index 0→1)
        'importmap',                            # javascript = importmap (index 1→2)
        'tailwind',                             # css = tailwind (index 2→3)
        CreateRailsApp::Wizard::BACK,           # back from hotwire → css (index 3→2)
        CreateRailsApp::Wizard::BACK,           # back from css → javascript (index 2→1)
        CreateRailsApp::Wizard::BACK,           # back from javascript → api (index 1→0)
        'yes' # api = yes (index 0→1, skips rest)
      ]
    )

    result = described_class.new(
      compatibility_entry: entry,
      defaults: {},
      prompter: prompter
    ).run

    expect(result[:api]).to be(true)
    # javascript, css, hotwire should be cleared — not stale from previous pass
    expect(result).not_to have_key(:javascript)
    expect(result).not_to have_key(:css)
    expect(result).not_to have_key(:hotwire)
  end

  it 'back-navigates past auto-skipped steps' do
    entry = CreateRailsApp::Compatibility::Matrix::Entry.new(
      requirement: Gem::Requirement.new('>= 0'),
      supported_options: {
        api: nil,
        javascript: %w[importmap bun],
        css: %w[tailwind],
        hotwire: nil,
        jbuilder: nil,
        action_text: nil,
        test: nil
      }
    )
    prompter = WizardFakePrompter.new(
      choices: [
        'yes',                                  # api = true (skips js, css, hotwire, jbuilder, action_text)
        CreateRailsApp::Wizard::BACK,           # back from test → should land on api (skipping auto-skipped steps)
        'no',                                   # api = no
        'importmap',                            # javascript
        'tailwind',                             # css
        'include',                              # hotwire
        'include',                              # jbuilder
        'include',                              # action_text
        'include'                               # test
      ]
    )

    result = described_class.new(
      compatibility_entry: entry,
      defaults: {},
      prompter: prompter
    ).run

    expect(result).not_to have_key(:api)
    expect(result[:javascript]).to eq('importmap')
  end
end
