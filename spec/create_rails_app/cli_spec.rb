# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

class CLIFakePrompter
  attr_reader :messages

  def initialize(choices: [], texts: [], confirms: [])
    @choices = choices
    @texts = texts
    @confirms = confirms
    @messages = []
  end

  def frame(_title)
    yield if block_given?
  end

  def choose(_question, options:, default: nil)
    value = @choices.shift
    return value if value

    default || options.first
  end

  def text(_question, default: nil, allow_empty: true)
    value = @texts.shift
    value = default if value.nil?
    value = '' if value.nil? && allow_empty
    value
  end

  def confirm(_question, default: true)
    value = @confirms.shift
    value.nil? ? default : value
  end

  def say(message)
    @messages << message
  end
end

RSpec.describe CreateRailsApp::CLI do
  let(:rails_detector) { instance_double(CreateRailsApp::Detection::RailsVersions) }
  let(:detector) { instance_double(CreateRailsApp::Detection::Runtime) }
  let(:runtime_info) do
    CreateRailsApp::Detection::RuntimeInfo.new(
      ruby: Gem::Version.new(RUBY_VERSION),
      rubygems: Gem::Version.new(Gem::VERSION)
    )
  end

  before do
    allow(detector).to receive(:detect).and_return(runtime_info)
    allow(rails_detector).to receive(:detect).and_return({ '8.1' => '8.1.2' })
  end

  it 'prints version with --version' do
    out = StringIO.new

    status = described_class.start(
      ['--version'],
      out: out,
      err: StringIO.new,
      store: instance_double(CreateRailsApp::Config::Store),
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(0)
    expect(out.string.strip).to eq(CreateRailsApp::VERSION)
  end

  it 'prints help with --help' do
    out = StringIO.new

    status = described_class.start(
      ['--help'],
      out: out,
      err: StringIO.new,
      store: instance_double(CreateRailsApp::Config::Store),
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(0)
    expect(out.string).to include('Usage: create-rails-app')
    expect(out.string).to include('--help')
    expect(out.string).to include('--preset')
  end

  it 'runs doctor and prints info' do
    out = StringIO.new

    status = described_class.start(
      ['--doctor'],
      out: out,
      err: StringIO.new,
      store: instance_double(CreateRailsApp::Config::Store),
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(0)
    expect(out.string).to include('ruby:')
    expect(out.string).to include('rails 8.1: 8.1.2')
    expect(out.string).to include('options')
  end

  it 'lists presets' do
    out = StringIO.new
    store = instance_double(CreateRailsApp::Config::Store, preset_names: %w[alpha beta])

    status = described_class.start(
      ['--list-presets'],
      out: out,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(0)
    expect(out.string).to include('alpha')
    expect(out.string).to include('beta')
  end

  it 'shows preset values' do
    out = StringIO.new
    store = instance_double(CreateRailsApp::Config::Store, preset: { 'database' => 'postgresql', 'api' => true })

    status = described_class.start(
      ['--show-preset', 'fast'],
      out: out,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(0)
    expect(out.string).to include('fast')
    expect(out.string).to include('database: "postgresql"')
  end

  it 'returns error for missing preset' do
    err = StringIO.new
    store = instance_double(CreateRailsApp::Config::Store, preset: nil)

    status = described_class.start(
      ['--show-preset', 'missing'],
      out: StringIO.new,
      err: err,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(1)
    expect(err.string).to include('Preset not found')
  end

  it 'delegates --delete-preset to store' do
    store = instance_double(CreateRailsApp::Config::Store)
    expect(store).to receive(:delete_preset).with('old')

    status = described_class.start(
      ['--delete-preset', 'old'],
      out: StringIO.new,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(0)
  end

  it 'rejects conflicting flags' do
    err = StringIO.new
    status = described_class.start(
      ['myapp', '--doctor'],
      out: StringIO.new,
      err: err,
      store: instance_double(CreateRailsApp::Config::Store),
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(1)
    expect(err.string).to include('--doctor cannot be combined')
  end

  it 'rejects --version combined with --doctor' do
    err = StringIO.new
    status = described_class.start(
      ['--version', '--doctor'],
      out: StringIO.new,
      err: err,
      store: instance_double(CreateRailsApp::Config::Store),
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(1)
    expect(err.string).to include('--version cannot be combined')
  end

  it 'returns error for unknown flags' do
    err = StringIO.new

    status = described_class.start(
      ['--unknown-flag'],
      out: StringIO.new,
      err: err,
      store: instance_double(CreateRailsApp::Config::Store),
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(1)
    expect(err.string).to include('invalid option')
  end

  it 'runs dry-run with --rails-version (installed)' do
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)
    expect(runner).to receive(:run!).with(
      satisfy { |cmd| cmd.first(4) == %w[rails _8.1.2_ new myapp] },
      dry_run: true
    )

    prompter = CLIFakePrompter.new(
      choices: ['create'],
      confirms: [false]
    )

    status = described_class.start(
      ['myapp', '--dry-run', '--rails-version', '8.1.2'],
      out: StringIO.new,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )

    expect(status).to eq(0)
  end

  it 'defers installation in dry-run when rails version not installed' do
    # Only 8.1 installed, requesting 7.2.0
    allow(rails_detector).to receive(:detect).and_return({ '8.1' => '8.1.2' })

    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)

    # First call: dry-run install command
    expect(runner).to receive(:run!).with(
      ['gem', 'install', 'rails', '-v', '7.2.0'],
      dry_run: true
    ).ordered

    # Second call: dry-run rails new (with version pin since exact version known)
    expect(runner).to receive(:run!).with(
      satisfy { |cmd| cmd.include?('new') && cmd.include?('myapp') },
      dry_run: true
    ).ordered

    prompter = CLIFakePrompter.new(
      choices: ['create'],
      confirms: [false]
    )

    status = described_class.start(
      ['myapp', '--dry-run', '--rails-version', '7.2.0'],
      out: StringIO.new,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )

    expect(status).to eq(0)
  end

  it 'installs rails with spinner when not installed' do
    # First detect: only 8.1 installed; second detect: 7.2 now installed
    allow(rails_detector).to receive(:detect).and_return(
      { '8.1' => '8.1.2' },
      { '8.1' => '8.1.2', '7.2' => '7.2.5' }
    )
    allow(CLI::UI::Spinner).to receive(:spin).and_yield

    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)

    expect(runner).to receive(:run!).with(
      ['gem', 'install', 'rails', '-v', '7.2.0']
    ).ordered

    expect(runner).to receive(:run!).with(
      satisfy { |cmd| cmd.first(4) == %w[rails _7.2.0_ new myapp] },
      dry_run: nil
    ).ordered

    prompter = CLIFakePrompter.new(
      choices: ['create'],
      confirms: [false]
    )

    status = described_class.start(
      ['myapp', '--rails-version', '7.2.0'],
      out: StringIO.new,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )

    expect(status).to eq(0)
  end

  it 'runs with preset' do
    store = instance_double(CreateRailsApp::Config::Store)
    allow(store).to receive(:last_used).and_return({})
    allow(store).to receive(:preset).with('fast').and_return({ 'database' => 'postgresql' })
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    status = described_class.start(
      ['myapp', '--preset', 'fast', '--dry-run', '--rails-version', '8.1.2'],
      out: StringIO.new,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: CLIFakePrompter.new(confirms: [false])
    )

    expect(status).to eq(0)
  end

  it 'returns error for missing app name with --preset' do
    err = StringIO.new
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})

    status = described_class.start(
      ['--preset', 'fast', '--rails-version', '8.1.2'],
      out: StringIO.new,
      err: err,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(1)
    expect(err.string).to include('App name is required')
  end

  it 'returns 130 on interrupt' do
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    runner = instance_double(CreateRailsApp::Runner)
    prompter = CLIFakePrompter.new
    allow(prompter).to receive(:choose).and_raise(Interrupt)

    err = StringIO.new
    status = described_class.start(
      ['myapp', '--rails-version', '8.1.2'],
      out: StringIO.new,
      err: err,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )

    expect(status).to eq(130)
    expect(err.string).to include('See ya!')
  end

  it 'prompts for app name when not provided' do
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)
    expect(runner).to receive(:run!).with(
      satisfy { |cmd| cmd.include?('prompted_app') },
      dry_run: true
    )
    prompter = CLIFakePrompter.new(
      texts: ['prompted_app'],
      choices: ['create'],
      confirms: [false]
    )

    status = described_class.start(
      ['--dry-run', '--rails-version', '8.1.2'],
      out: StringIO.new,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )

    expect(status).to eq(0)
  end

  it 'passes --minimal through to command builder' do
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)
    expect(runner).to receive(:run!).with(
      satisfy { |cmd| cmd.include?('--minimal') },
      dry_run: true
    )
    prompter = CLIFakePrompter.new(
      choices: ['create'],
      confirms: [false]
    )

    status = described_class.start(
      ['myapp', '--dry-run', '--rails-version', '8.1.2', '--minimal'],
      out: StringIO.new,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )

    expect(status).to eq(0)
  end

  it 'rejects --delete-preset combined with create actions' do
    err = StringIO.new
    status = described_class.start(
      ['myapp', '--delete-preset', 'old'],
      out: StringIO.new,
      err: err,
      store: instance_double(CreateRailsApp::Config::Store),
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(1)
    expect(err.string).to include('--delete-preset cannot be combined')
  end

  it 'shows series labels for version selection' do
    allow(rails_detector).to receive(:detect).and_return({ '8.1' => '8.1.2' })

    prompter = CLIFakePrompter.new
    all_seen_options = []
    allow(prompter).to receive(:choose) do |_question, options:, **_kwargs|
      all_seen_options << options
      options.first
    end
    allow(prompter).to receive(:frame).and_yield
    allow(prompter).to receive(:say)
    allow(prompter).to receive(:text).and_return('myapp')
    allow(prompter).to receive(:confirm).and_return(false)

    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    described_class.start(
      ['--dry-run'],
      out: StringIO.new,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )

    version_options = all_seen_options.first
    expect(version_options).to eq(['Rails 8.1', 'Rails 8.0 (not installed)', 'Rails 7.2 (not installed)'])
  end

  it 'shows install line in summary when rails needs installation' do
    allow(rails_detector).to receive(:detect).and_return({ '8.1' => '8.1.2' })

    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    prompter = CLIFakePrompter.new(
      choices: ['create'],
      confirms: [false]
    )

    described_class.start(
      ['myapp', '--dry-run', '--rails-version', '7.2.0'],
      out: StringIO.new,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )

    install_msg = prompter.messages.find { |m| m.include?('gem install rails') }
    expect(install_msg).not_to be_nil
  end

  it 'raises error when rails detection fails after installation' do
    # First detect: nothing installed. Second detect (after install): still nothing.
    allow(rails_detector).to receive(:detect).and_return({}, {})
    allow(CLI::UI::Spinner).to receive(:spin).and_yield

    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    # Interactive: select "Rails 8.1" (no exact version → version_choice.version is nil)
    prompter = CLIFakePrompter.new(choices: ['Rails 8.1 (not installed)', 'create'], confirms: [false])
    err = StringIO.new

    status = described_class.start(
      ['myapp'],
      out: StringIO.new,
      err: err,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )

    expect(status).to eq(1)
    expect(err.string).to include('Failed to detect Rails')
  end

  it 'triggers installation when exact patch version differs from installed' do
    # 8.1.2 installed, but 8.1.5 requested — exact version mismatch
    allow(rails_detector).to receive(:detect).and_return({ '8.1' => '8.1.2' })

    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)

    expect(runner).to receive(:run!).with(
      ['gem', 'install', 'rails', '-v', '8.1.5'],
      dry_run: true
    ).ordered

    expect(runner).to receive(:run!).with(
      satisfy { |cmd| cmd.include?('_8.1.5_') && cmd.include?('new') },
      dry_run: true
    ).ordered

    prompter = CLIFakePrompter.new(
      choices: ['create'],
      confirms: [false]
    )

    status = described_class.start(
      ['myapp', '--dry-run', '--rails-version', '8.1.5'],
      out: StringIO.new,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )

    expect(status).to eq(0)
  end

  it 'rejects single-segment --rails-version' do
    err = StringIO.new

    status = described_class.start(
      ['myapp', '--rails-version', '8'],
      out: StringIO.new,
      err: err,
      store: instance_double(CreateRailsApp::Config::Store),
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(1)
    expect(err.string).to include('major.minor')
  end

  it 'saves preset with --save-preset flag' do
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:preset).with('mypreset').and_return(nil)
    expect(store).to receive(:save_preset).with('mypreset', anything)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    prompter = CLIFakePrompter.new(choices: ['create'], confirms: [false])

    status = described_class.start(
      ['myapp', '--rails-version', '8.1.2', '--save-preset', 'mypreset'],
      out: StringIO.new,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )

    expect(status).to eq(0)
  end

  it 'skips save when user declines overwrite of existing preset' do
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:preset).with('existing').and_return({ 'api' => true })
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    # confirms: [false] for overwrite prompt, then false for "save as preset?"
    prompter = CLIFakePrompter.new(choices: ['create'], confirms: [false, false])

    status = described_class.start(
      ['myapp', '--rails-version', '8.1.2', '--save-preset', 'existing'],
      out: StringIO.new,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )

    expect(status).to eq(0)
    expect(store).not_to have_received(:save_preset)
  end

  it 'saves preset interactively when user confirms' do
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:preset).with('newpreset').and_return(nil)
    expect(store).to receive(:save_preset).with('newpreset', anything)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    # confirms: [true] for "save as preset?"
    prompter = CLIFakePrompter.new(
      choices: ['create'],
      confirms: [true],
      texts: ['newpreset']
    )

    status = described_class.start(
      ['myapp', '--rails-version', '8.1.2'],
      out: StringIO.new,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )

    expect(status).to eq(0)
  end

  it 'rejects invalid --save-preset name before running command' do
    store = instance_double(CreateRailsApp::Config::Store)
    runner = instance_double(CreateRailsApp::Runner)
    expect(runner).not_to receive(:run!)

    err = StringIO.new

    status = described_class.start(
      ['myapp', '--dry-run', '--rails-version', '8.1.2', '--save-preset', '!!!'],
      out: StringIO.new,
      err: err,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(1)
    expect(err.string).to include('Invalid preset name')
  end

  it 'returns error for invalid --rails-version' do
    err = StringIO.new

    status = described_class.start(
      ['myapp', '--rails-version', 'not-a-version'],
      out: StringIO.new,
      err: err,
      store: instance_double(CreateRailsApp::Config::Store),
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(1)
    expect(err.string).not_to be_empty
  end

  it 'does not save last_used on dry-run' do
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    expect(store).not_to receive(:save_last_used)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    prompter = CLIFakePrompter.new(
      choices: ['create'],
      confirms: [false]
    )

    described_class.start(
      ['myapp', '--dry-run', '--rails-version', '8.1.2'],
      out: StringIO.new,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )
  end

  it 'rejects --dry-run combined with --delete-preset' do
    err = StringIO.new
    status = described_class.start(
      ['--dry-run', '--delete-preset', 'old'],
      out: StringIO.new,
      err: err,
      store: instance_double(CreateRailsApp::Config::Store),
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(1)
    expect(err.string).to include('--dry-run cannot be combined')
  end

  it 'rejects --version combined with --dry-run' do
    err = StringIO.new
    status = described_class.start(
      ['--version', '--dry-run'],
      out: StringIO.new,
      err: err,
      store: instance_double(CreateRailsApp::Config::Store),
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(1)
    expect(err.string).to include('--version cannot be combined')
  end

  it 'rejects --doctor combined with --dry-run' do
    err = StringIO.new
    status = described_class.start(
      ['--doctor', '--dry-run'],
      out: StringIO.new,
      err: err,
      store: instance_double(CreateRailsApp::Config::Store),
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(1)
    expect(err.string).to include('--doctor cannot be combined')
  end

  it 'rejects --dry-run combined with --list-presets' do
    err = StringIO.new
    status = described_class.start(
      ['--dry-run', '--list-presets'],
      out: StringIO.new,
      err: err,
      store: instance_double(CreateRailsApp::Config::Store),
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(1)
    expect(err.string).to include('--dry-run cannot be combined')
  end

  it 'handles app named "new" in summary without error' do
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    prompter = CLIFakePrompter.new(
      choices: ['create'],
      confirms: [false]
    )

    status = described_class.start(
      ['new', '--dry-run', '--rails-version', '8.1.2'],
      out: StringIO.new,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )

    expect(status).to eq(0)
  end

  it 'returns exit 0 when config write fails after successful creation' do
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used).and_raise(
      CreateRailsApp::ConfigError, 'Failed to write config'
    )
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    prompter = CLIFakePrompter.new(
      choices: ['create'],
      confirms: [false]
    )
    err = StringIO.new

    status = described_class.start(
      ['myapp', '--rails-version', '8.1.2'],
      out: StringIO.new,
      err: err,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )

    expect(status).to eq(0)
    expect(err.string).to include('Warning:')
  end

  it 'returns exit 0 when preset save fails after successful creation' do
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    # confirms: [true] to save preset, text '!!!' is invalid preset name
    prompter = CLIFakePrompter.new(
      choices: ['create'],
      confirms: [true],
      texts: ['!!!']
    )

    err = StringIO.new
    status = described_class.start(
      ['myapp', '--rails-version', '8.1.2'],
      out: StringIO.new,
      err: err,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )

    expect(status).to eq(0)
    expect(err.string).to include('Warning:')
  end

  it 'shows "(not installed)" for uninstalled series' do
    allow(rails_detector).to receive(:detect).and_return({ '8.1' => '8.1.2' })

    prompter = CLIFakePrompter.new
    all_seen_options = []
    allow(prompter).to receive(:choose) do |_question, options:, **_kwargs|
      all_seen_options << options
      options.first
    end
    allow(prompter).to receive(:frame).and_yield
    allow(prompter).to receive(:say)
    allow(prompter).to receive(:text).and_return('myapp')
    allow(prompter).to receive(:confirm).and_return(false)

    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    described_class.start(
      ['--dry-run'],
      out: StringIO.new,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )

    version_options = all_seen_options.first
    installed_option = version_options.find { |o| o.include?('8.1') }
    expect(installed_option).not_to include('not installed')

    uninstalled_option = version_options.find { |o| o.include?('8.0') }
    expect(uninstalled_option).to include('(not installed)')
  end

  it 'returns error for nonexistent preset' do
    err = StringIO.new
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:preset).with('nope').and_return(nil)

    status = described_class.start(
      ['myapp', '--preset', 'nope', '--rails-version', '8.1.2'],
      out: StringIO.new,
      err: err,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(1)
    expect(err.string).to include('Preset not found')
  end

  it 'supports edit-again wizard loop' do
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    prompter = CLIFakePrompter.new(
      choices: ['edit again', 'create'],
      confirms: [false]
    )

    status = described_class.start(
      ['myapp', '--dry-run', '--rails-version', '8.1.2'],
      out: StringIO.new,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )

    expect(status).to eq(0)
  end

  it 'runs --doctor with no rails installed' do
    allow(rails_detector).to receive(:detect).and_return({})
    out = StringIO.new

    status = described_class.start(
      ['--doctor'],
      out: out,
      err: StringIO.new,
      store: instance_double(CreateRailsApp::Config::Store),
      detector: detector,
      rails_detector: rails_detector,
      runner: instance_double(CreateRailsApp::Runner),
      prompter: CLIFakePrompter.new
    )

    expect(status).to eq(0)
    expect(out.string).to include('not installed')
  end

  it 'selects uninstalled rails version interactively and installs it' do
    # No rails installed at all
    allow(rails_detector).to receive(:detect).and_return(
      {},
      { '8.1' => '8.1.0' }
    )
    allow(CLI::UI::Spinner).to receive(:spin).and_yield

    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    prompter = CLIFakePrompter.new(
      choices: ['Rails 8.1 (not installed)', 'create'],
      confirms: [false]
    )

    status = described_class.start(
      ['myapp'],
      out: StringIO.new,
      err: StringIO.new,
      store: store,
      detector: detector,
      rails_detector: rails_detector,
      runner: runner,
      prompter: prompter
    )

    expect(status).to eq(0)
    expect(runner).to have_received(:run!).with(
      satisfy { |cmd| cmd.include?('gem') && cmd.include?('install') }
    )
  end
end
