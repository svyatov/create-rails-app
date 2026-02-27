# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CreateRailsApp::Options::Validator do
  subject(:validator) { described_class.new(entry) }

  let(:entry) { CreateRailsApp::Compatibility::Matrix.for('8.1.0') }

  it 'accepts valid options' do
    expect(
      validator.validate!(
        app_name: 'myapp',
        options: { database: 'postgresql', api: true, hotwire: false }
      )
    ).to be(true)
  end

  it 'rejects invalid app name' do
    expect do
      validator.validate!(app_name: '1bad', options: {})
    end.to raise_error(CreateRailsApp::ValidationError, /Invalid app name/)
  end

  it 'rejects unknown options' do
    expect do
      validator.validate!(app_name: 'myapp', options: { unknown: true })
    end.to raise_error(CreateRailsApp::ValidationError, /Unknown option/)
  end

  it 'rejects unsupported option for entry' do
    old_entry = CreateRailsApp::Compatibility::Matrix.for('7.2.0')
    old_validator = described_class.new(old_entry)

    expect do
      old_validator.validate!(app_name: 'myapp', options: { kamal: true })
    end.to raise_error(CreateRailsApp::ValidationError, /not supported/)
  end

  it 'rejects invalid value for skip type' do
    expect do
      validator.validate!(app_name: 'myapp', options: { hotwire: 'yes' })
    end.to raise_error(CreateRailsApp::ValidationError, /Invalid value/)
  end

  it 'rejects invalid value for flag type' do
    expect do
      validator.validate!(app_name: 'myapp', options: { api: 'yes' })
    end.to raise_error(CreateRailsApp::ValidationError, /Invalid value/)
  end

  it 'rejects empty string app name' do
    expect do
      validator.validate!(app_name: '', options: {})
    end.to raise_error(CreateRailsApp::ValidationError, /Invalid app name/)
  end

  it 'rejects nil app name' do
    expect do
      validator.validate!(app_name: nil, options: {})
    end.to raise_error(CreateRailsApp::ValidationError, /Invalid app name/)
  end

  it 'accepts nil value for any option type' do
    expect(
      validator.validate!(app_name: 'myapp', options: { api: nil, database: nil, hotwire: nil })
    ).to be(true)
  end

  it 'rejects unsupported enum value' do
    expect do
      validator.validate!(app_name: 'myapp', options: { database: 'oracle' })
    end.to raise_error(CreateRailsApp::ValidationError, /Invalid value/)
  end

  it 'accepts false for flag type' do
    expect(
      validator.validate!(app_name: 'myapp', options: { api: false })
    ).to be(true)
  end

  it 'rejects false for enum without :none key' do
    expect do
      validator.validate!(app_name: 'myapp', options: { database: false })
    end.to raise_error(CreateRailsApp::ValidationError, /Invalid value/)
  end

  it 'accepts false for enum with :none key' do
    expect(
      validator.validate!(app_name: 'myapp', options: { javascript: false })
    ).to be(true)
  end

  it 'accepts true for enum with :none key (include with default)' do
    expect(
      validator.validate!(app_name: 'myapp', options: { asset_pipeline: true })
    ).to be(true)
  end

  it 'rejects true for enum without :none key' do
    expect do
      validator.validate!(app_name: 'myapp', options: { database: true })
    end.to raise_error(CreateRailsApp::ValidationError, /Invalid value/)
  end

  it 'rejects enum string value when compatibility matrix returns nil' do
    entry_eight = CreateRailsApp::Compatibility::Matrix.for('8.0.0')
    validator_eight = described_class.new(entry_eight)

    expect do
      validator_eight.validate!(app_name: 'myapp', options: { asset_pipeline: 'sprockets' })
    end.to raise_error(CreateRailsApp::ValidationError, /not supported by this Rails version/)
  end

  it 'rejects enum value that passes type check but fails compatibility check' do
    # Create an entry that supports database but only allows sqlite3
    restricted_entry = CreateRailsApp::Compatibility::Matrix::Entry.new(
      requirement: Gem::Requirement.new('>= 0'),
      supported_options: { database: %w[sqlite3] }
    )
    restricted_validator = described_class.new(restricted_entry)

    expect do
      restricted_validator.validate!(app_name: 'myapp', options: { database: 'postgresql' })
    end.to raise_error(CreateRailsApp::ValidationError, /not supported by this Rails version/)
  end
end
