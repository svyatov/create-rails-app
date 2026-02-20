# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe CreateRailsApp::Config::Store do
  let(:tmpdir) { Dir.mktmpdir('create-rails-app-test') }
  let(:config_path) { File.join(tmpdir, 'config.yml') }
  let(:store) { described_class.new(path: config_path) }

  after { FileUtils.rm_rf(tmpdir) }

  it 'returns empty last_used when no file exists' do
    expect(store.last_used).to eq({})
  end

  it 'saves and loads last_used' do
    store.save_last_used(database: 'postgresql', api: true)
    loaded = store.last_used

    expect(loaded).to eq('database' => 'postgresql', 'api' => true)
  end

  it 'saves and loads a preset' do
    store.save_preset('fast', database: 'sqlite3', hotwire: false)
    preset = store.preset('fast')

    expect(preset).to eq('database' => 'sqlite3', 'hotwire' => false)
  end

  it 'returns nil for missing preset' do
    expect(store.preset('missing')).to be_nil
  end

  it 'lists preset names sorted' do
    store.save_preset('beta', api: true)
    store.save_preset('alpha', api: false)

    expect(store.preset_names).to eq(%w[alpha beta])
  end

  it 'deletes a preset' do
    store.save_preset('temp', database: 'mysql')
    store.delete_preset('temp')

    expect(store.preset('temp')).to be_nil
  end

  it 'no-ops when deleting missing preset' do
    expect { store.delete_preset('missing') }.not_to raise_error
  end

  it 'raises ConfigError on corrupt YAML' do
    File.write(config_path, "---\n\t\tinvalid: yaml: broken")
    expect { store.last_used }.to raise_error(CreateRailsApp::ConfigError, /Invalid config file/)
  end

  it 'raises ConfigError when directory cannot be created' do
    bad_store = described_class.new(path: '/dev/null/impossible/config.yml')

    expect do
      bad_store.save_last_used(database: 'postgresql')
    end.to raise_error(CreateRailsApp::ConfigError, /Failed to write config/)
  end
end
