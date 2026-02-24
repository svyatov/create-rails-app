# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require_relative '../support/fake_prompter'

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

  # @param argv [Array<String>]
  # @return [Integer] exit code
  def run_cli(argv, out: StringIO.new, err: StringIO.new, store: nil, runner: nil, prompter: nil)
    described_class.start(
      argv,
      out: out, err: err,
      store: store || instance_double(CreateRailsApp::Config::Store),
      detector: detector,
      rails_detector: rails_detector,
      runner: runner || instance_double(CreateRailsApp::Runner),
      prompter: prompter || FakePrompter.new
    )
  end

  it 'prints version with --version' do
    out = StringIO.new
    expect(run_cli(['--version'], out: out)).to eq(0)
    expect(out.string.strip).to eq(CreateRailsApp::VERSION)
  end

  it 'prints help with --help' do
    out = StringIO.new
    expect(run_cli(['--help'], out: out)).to eq(0)
    expect(out.string).to include('Usage: create-rails-app')
    expect(out.string).to include('--help')
    expect(out.string).to include('--preset')
  end

  it 'runs doctor and prints info' do
    out = StringIO.new
    expect(run_cli(['--doctor'], out: out)).to eq(0)
    expect(out.string).to include('ruby:')
    expect(out.string).to include('rails 8.1: 8.1.2')
    expect(out.string).to include('options')
  end

  it 'lists presets' do
    out = StringIO.new
    store = instance_double(CreateRailsApp::Config::Store, preset_names: %w[alpha beta])
    expect(run_cli(['--list-presets'], out: out, store: store)).to eq(0)
    expect(out.string).to include('alpha')
    expect(out.string).to include('beta')
  end

  it 'shows preset values' do
    out = StringIO.new
    store = instance_double(CreateRailsApp::Config::Store, preset: { 'database' => 'postgresql', 'api' => true })
    expect(run_cli(['--show-preset', 'fast'], out: out, store: store)).to eq(0)
    expect(out.string).to include('fast')
    expect(out.string).to include('database: "postgresql"')
  end

  it 'returns error for missing preset' do
    err = StringIO.new
    store = instance_double(CreateRailsApp::Config::Store, preset: nil)
    expect(run_cli(['--show-preset', 'missing'], err: err, store: store)).to eq(1)
    expect(err.string).to include('Preset not found')
  end

  it 'delegates --delete-preset to store' do
    store = instance_double(CreateRailsApp::Config::Store)
    expect(store).to receive(:delete_preset).with('old')
    expect(run_cli(['--delete-preset', 'old'], store: store)).to eq(0)
  end

  {
    %w[myapp --doctor] => '--doctor cannot be combined',
    %w[--version --doctor] => '--version cannot be combined',
    %w[myapp --delete-preset old] => '--delete-preset cannot be combined',
    %w[--dry-run --delete-preset old] => '--dry-run cannot be combined',
    %w[--version --dry-run] => '--version cannot be combined',
    %w[--doctor --dry-run] => '--doctor cannot be combined',
    %w[--dry-run --list-presets] => '--dry-run cannot be combined',
    %w[--list-presets --show-preset foo] => '--list-presets and --show-preset cannot be combined',
    %w[--list-presets --preset fast myapp] => 'Preset query options cannot be combined',
    %w[--show-preset foo --save-preset bar myapp] => 'Preset query options cannot be combined',
    %w[myapp --minimal --preset fast] => '--minimal cannot be combined with --preset',
    %w[myapp --minimal --save-preset fast] => '--minimal cannot be combined with --save-preset'
  }.each do |argv, msg|
    it "rejects #{argv.join(' ')}" do
      err = StringIO.new
      expect(run_cli(argv, err: err)).to eq(1)
      expect(err.string).to include(msg)
    end
  end

  it 'returns error for unknown flags' do
    err = StringIO.new
    expect(run_cli(['--unknown-flag'], err: err)).to eq(1)
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

    status = run_cli(
      ['myapp', '--dry-run', '--rails-version', '8.1.2'],
      store: store, runner: runner,
      prompter: FakePrompter.new(choices: ['create'], confirms: [false])
    )
    expect(status).to eq(0)
  end

  it 'defers installation in dry-run when rails version not installed' do
    allow(rails_detector).to receive(:detect).and_return({ '8.1' => '8.1.2' })

    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)

    expect(runner).to receive(:run!).with(
      ['gem', 'install', 'rails', '-v', '7.2.0'], dry_run: true
    ).ordered
    expect(runner).to receive(:run!).with(
      satisfy { |cmd| cmd.include?('new') && cmd.include?('myapp') }, dry_run: true
    ).ordered

    status = run_cli(
      ['myapp', '--dry-run', '--rails-version', '7.2.0'],
      store: store, runner: runner,
      prompter: FakePrompter.new(choices: ['create'], confirms: [false])
    )
    expect(status).to eq(0)
  end

  it 'installs rails with spinner when not installed' do
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
      satisfy { |cmd| cmd.first(4) == %w[rails _7.2.0_ new myapp] }, dry_run: false
    ).ordered

    status = run_cli(
      ['myapp', '--rails-version', '7.2.0'],
      store: store, runner: runner,
      prompter: FakePrompter.new(choices: ['create'], confirms: [false])
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

    status = run_cli(
      ['myapp', '--preset', 'fast', '--dry-run', '--rails-version', '8.1.2'],
      store: store, runner: runner,
      prompter: FakePrompter.new(confirms: [false])
    )
    expect(status).to eq(0)
  end

  it 'returns error for missing app name with --preset' do
    err = StringIO.new
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    expect(run_cli(['--preset', 'fast', '--rails-version', '8.1.2'], err: err, store: store)).to eq(1)
    expect(err.string).to include('App name is required')
  end

  it 'returns 130 on interrupt' do
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    prompter = FakePrompter.new
    allow(prompter).to receive(:choose).and_raise(Interrupt)

    err = StringIO.new
    status = run_cli(
      ['myapp', '--rails-version', '8.1.2'],
      err: err, store: store, prompter: prompter
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
      satisfy { |cmd| cmd.include?('prompted_app') }, dry_run: true
    )

    status = run_cli(
      ['--dry-run', '--rails-version', '8.1.2'],
      store: store, runner: runner,
      prompter: FakePrompter.new(texts: ['prompted_app'], choices: ['create'], confirms: [false])
    )
    expect(status).to eq(0)
  end

  it 'passes --minimal directly without wizard or store' do
    store = instance_double(CreateRailsApp::Config::Store)
    runner = instance_double(CreateRailsApp::Runner)
    expect(runner).to receive(:run!).with(
      %w[rails _8.1.2_ new myapp --minimal], dry_run: true
    )

    status = run_cli(
      ['myapp', '--dry-run', '--rails-version', '8.1.2', '--minimal'],
      store: store, runner: runner
    )
    expect(status).to eq(0)
  end

  it 'shows series labels for version selection' do
    allow(rails_detector).to receive(:detect).and_return({ '8.1' => '8.1.2' })

    prompter = FakePrompter.new
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

    run_cli(['--dry-run'], store: store, runner: runner, prompter: prompter)

    version_options = all_seen_options.first
    expect(version_options).to eq(['Rails 8.1', 'Rails 8.0 (not installed)', 'Rails 7.2 (not installed)'])
  end

  it 'shows version pin in summary when using older rails version' do
    allow(rails_detector).to receive(:detect).and_return({ '8.1' => '8.1.2' })

    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    prompter = FakePrompter.new(choices: ['create'], confirms: [false])

    run_cli(
      ['myapp', '--dry-run', '--rails-version', '7.2.0'],
      store: store, runner: runner, prompter: prompter
    )

    command_msg = prompter.messages.find { |m| m.include?('rails') && m.include?('new') && m.include?('myapp') }
    expect(command_msg).to include('_7.2.0_')
  end

  it 'shows install line in summary when rails needs installation' do
    allow(rails_detector).to receive(:detect).and_return({ '8.1' => '8.1.2' })

    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    prompter = FakePrompter.new(choices: ['create'], confirms: [false])

    run_cli(
      ['myapp', '--dry-run', '--rails-version', '7.2.0'],
      store: store, runner: runner, prompter: prompter
    )

    install_msg = prompter.messages.find { |m| m.include?('gem install rails') }
    expect(install_msg).not_to be_nil
  end

  it 'raises error when rails detection fails after installation' do
    allow(rails_detector).to receive(:detect).and_return({}, {})
    allow(CLI::UI::Spinner).to receive(:spin).and_yield

    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    err = StringIO.new
    status = run_cli(
      ['myapp'],
      err: err, store: store, runner: runner,
      prompter: FakePrompter.new(choices: ['Rails 8.1 (not installed)', 'create'], confirms: [false])
    )
    expect(status).to eq(1)
    expect(err.string).to include('Failed to detect Rails')
  end

  it 'triggers installation when exact patch version differs from installed' do
    allow(rails_detector).to receive(:detect).and_return({ '8.1' => '8.1.2' })

    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)

    expect(runner).to receive(:run!).with(
      ['gem', 'install', 'rails', '-v', '8.1.5'], dry_run: true
    ).ordered
    expect(runner).to receive(:run!).with(
      satisfy { |cmd| cmd.include?('_8.1.5_') && cmd.include?('new') }, dry_run: true
    ).ordered

    status = run_cli(
      ['myapp', '--dry-run', '--rails-version', '8.1.5'],
      store: store, runner: runner,
      prompter: FakePrompter.new(choices: ['create'], confirms: [false])
    )
    expect(status).to eq(0)
  end

  it 'rejects single-segment --rails-version' do
    err = StringIO.new
    expect(run_cli(['myapp', '--rails-version', '8'], err: err)).to eq(1)
    expect(err.string).to include('major.minor')
  end

  it 'saves preset with --save-preset flag' do
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:preset).with('mypreset').and_return(nil)
    expect(store).to receive(:save_preset).with('mypreset', anything)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    status = run_cli(
      ['myapp', '--rails-version', '8.1.2', '--save-preset', 'mypreset'],
      store: store, runner: runner,
      prompter: FakePrompter.new(choices: ['create'], confirms: [false])
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

    status = run_cli(
      ['myapp', '--rails-version', '8.1.2', '--save-preset', 'existing'],
      store: store, runner: runner,
      prompter: FakePrompter.new(choices: ['create'], confirms: [false, false])
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

    status = run_cli(
      ['myapp', '--rails-version', '8.1.2'],
      store: store, runner: runner,
      prompter: FakePrompter.new(choices: ['create'], confirms: [true], texts: ['newpreset'])
    )
    expect(status).to eq(0)
  end

  it 'rejects invalid --save-preset name before running command' do
    runner = instance_double(CreateRailsApp::Runner)
    expect(runner).not_to receive(:run!)

    err = StringIO.new
    status = run_cli(
      ['myapp', '--dry-run', '--rails-version', '8.1.2', '--save-preset', '!!!'],
      err: err, runner: runner
    )
    expect(status).to eq(1)
    expect(err.string).to include('Invalid preset name')
  end

  it 'returns error for invalid --rails-version' do
    err = StringIO.new
    expect(run_cli(['myapp', '--rails-version', 'not-a-version'], err: err)).to eq(1)
    expect(err.string).to include('Malformed version number string')
  end

  it 'does not save last_used on dry-run' do
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    expect(store).not_to receive(:save_last_used)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    run_cli(
      ['myapp', '--dry-run', '--rails-version', '8.1.2'],
      store: store, runner: runner,
      prompter: FakePrompter.new(choices: ['create'], confirms: [false])
    )
  end

  it 'handles app named "new" in summary without error' do
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    status = run_cli(
      ['new', '--dry-run', '--rails-version', '8.1.2'],
      store: store, runner: runner,
      prompter: FakePrompter.new(choices: ['create'], confirms: [false])
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

    err = StringIO.new
    status = run_cli(
      ['myapp', '--rails-version', '8.1.2'],
      err: err, store: store, runner: runner,
      prompter: FakePrompter.new(choices: ['create'], confirms: [false])
    )
    expect(status).to eq(0)
    expect(err.string).to include('Warning:')
  end

  it 'returns exit 0 when preset save fails after successful creation' do
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    err = StringIO.new
    status = run_cli(
      ['myapp', '--rails-version', '8.1.2'],
      err: err, store: store, runner: runner,
      prompter: FakePrompter.new(choices: ['create'], confirms: [true], texts: ['!!!'])
    )
    expect(status).to eq(0)
    expect(err.string).to include('Warning:')
  end

  it 'shows "(not installed)" for uninstalled series' do
    allow(rails_detector).to receive(:detect).and_return({ '8.1' => '8.1.2' })

    prompter = FakePrompter.new
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

    run_cli(['--dry-run'], store: store, runner: runner, prompter: prompter)

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

    expect(run_cli(['myapp', '--preset', 'nope', '--rails-version', '8.1.2'], err: err, store: store)).to eq(1)
    expect(err.string).to include('Preset not found')
  end

  it 'supports edit-again wizard loop' do
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    status = run_cli(
      ['myapp', '--dry-run', '--rails-version', '8.1.2'],
      store: store, runner: runner,
      prompter: FakePrompter.new(choices: ['edit again', 'create'], confirms: [false])
    )
    expect(status).to eq(0)
  end

  it 'runs --doctor with no rails installed' do
    allow(rails_detector).to receive(:detect).and_return({})
    out = StringIO.new
    expect(run_cli(['--doctor'], out: out)).to eq(0)
    expect(out.string).to include('not installed')
  end

  it 'selects uninstalled rails version interactively and installs it' do
    allow(rails_detector).to receive(:detect).and_return({}, { '8.1' => '8.1.0' })
    allow(CLI::UI::Spinner).to receive(:spin).and_yield

    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    status = run_cli(
      ['myapp'],
      store: store, runner: runner,
      prompter: FakePrompter.new(choices: ['Rails 8.1 (not installed)', 'create'], confirms: [false])
    )
    expect(status).to eq(0)
    expect(runner).to have_received(:run!).with(
      satisfy { |cmd| cmd.include?('gem') && cmd.include?('install') }
    )
  end

  it 'prints message when BACK pressed at app-name prompt' do
    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)
    allow(runner).to receive(:run!)

    err = StringIO.new
    status = run_cli(
      ['--dry-run', '--rails-version', '8.1.2'],
      err: err, store: store, runner: runner,
      prompter: FakePrompter.new(texts: [CreateRailsApp::Wizard::BACK, 'myapp'], choices: ['create'], confirms: [false])
    )
    expect(status).to eq(0)
    expect(err.string).to include('Nothing to go back to.')
  end

  it 'skips install when installed version is higher than requested' do
    allow(rails_detector).to receive(:detect).and_return({ '8.1' => '8.1.5' })

    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)
    expect(runner).to receive(:run!).once.with(
      satisfy { |cmd| cmd.include?('_8.1.5_') && cmd.include?('new') }, dry_run: true
    )

    status = run_cli(
      ['myapp', '--dry-run', '--rails-version', '8.1.2'],
      store: store, runner: runner,
      prompter: FakePrompter.new(choices: ['create'], confirms: [false])
    )
    expect(status).to eq(0)
  end

  it 'skips install when --rails-version matches installed (Gem::Version comparison)' do
    allow(rails_detector).to receive(:detect).and_return({ '8.1' => '8.1.0' })

    store = instance_double(CreateRailsApp::Config::Store, last_used: {})
    allow(store).to receive(:save_last_used)
    allow(store).to receive(:save_preset)
    runner = instance_double(CreateRailsApp::Runner)
    expect(runner).to receive(:run!).once.with(
      satisfy { |cmd| cmd.include?('new') && cmd.include?('myapp') }, dry_run: true
    )

    status = run_cli(
      ['myapp', '--dry-run', '--rails-version', '8.1'],
      store: store, runner: runner,
      prompter: FakePrompter.new(choices: ['create'], confirms: [false])
    )
    expect(status).to eq(0)
  end
end
