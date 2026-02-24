# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CreateRailsApp::CommandBuilder do
  subject(:builder) { described_class.new }

  it 'builds a rails new command with version pinning' do
    command = builder.build(
      app_name: 'myapp',
      rails_version: '8.1.2',
      options: {
        api: true,
        database: 'postgresql',
        hotwire: false,
        kamal: false
      }
    )

    expect(command).to eq(
      [
        'rails', '_8.1.2_', 'new', 'myapp',
        '--api',
        '--database=postgresql',
        '--skip-hotwire',
        '--skip-kamal'
      ]
    )
  end

  it 'emits --skip-X for skip type set to false' do
    command = builder.build(
      app_name: 'myapp',
      rails_version: '8.1.0',
      options: { jbuilder: false, docker: false, bootsnap: false }
    )
    expect(command).to include('--skip-jbuilder', '--skip-docker', '--skip-bootsnap')
  end

  it 'emits nothing for skip type set to true' do
    command = builder.build(
      app_name: 'myapp',
      rails_version: '8.1.0',
      options: { hotwire: true }
    )
    expect(command).to eq(%w[rails _8.1.0_ new myapp])
  end

  it 'emits enum flag with value' do
    command = builder.build(
      app_name: 'myapp',
      rails_version: '8.1.0',
      options: { css: 'tailwind', javascript: 'importmap' }
    )
    expect(command).to include('--javascript=importmap', '--css=tailwind')
  end

  it 'emits enum skip flag when false and none is a flag string' do
    command = builder.build(
      app_name: 'myapp',
      rails_version: '8.1.0',
      options: { javascript: false }
    )
    expect(command).to include('--skip-javascript')
  end

  it 'emits nothing for enum false when none is boolean true (no skip flag exists)' do
    command = builder.build(
      app_name: 'myapp',
      rails_version: '8.1.0',
      options: { css: false }
    )
    expect(command).to eq(%w[rails _8.1.0_ new myapp])
  end

  it 'emits --api for flag type' do
    command = builder.build(
      app_name: 'myapp',
      rails_version: '8.1.0',
      options: { api: true }
    )
    expect(command).to include('--api')
  end

  it 'does not emit flag when nil' do
    command = builder.build(
      app_name: 'myapp',
      rails_version: '8.1.0',
      options: { api: nil }
    )
    expect(command).not_to include('--api')
  end

  it 'includes --minimal when requested' do
    command = builder.build(
      app_name: 'myapp',
      rails_version: '8.1.0',
      minimal: true
    )
    expect(command).to eq(%w[rails _8.1.0_ new myapp --minimal])
  end

  it 'builds minimal command with no options' do
    command = builder.build(app_name: 'myapp', rails_version: '8.1.0')
    expect(command).to eq(%w[rails _8.1.0_ new myapp])
  end

  it 'does not emit nil for enum false without :none key' do
    command = builder.build(
      app_name: 'myapp',
      rails_version: '8.1.0',
      options: { database: false }
    )
    expect(command).to eq(%w[rails _8.1.0_ new myapp])
  end

  it 'omits version pin when rails_version is nil' do
    command = builder.build(app_name: 'myapp', options: { database: 'postgresql' })
    expect(command).to eq(%w[rails new myapp --database=postgresql])
  end

  it 'emits --asset-pipeline=sprockets for enum value' do
    command = builder.build(
      app_name: 'myapp',
      rails_version: '7.2.0',
      options: { asset_pipeline: 'sprockets' }
    )
    expect(command).to include('--asset-pipeline=sprockets')
  end

  it 'emits --skip-asset-pipeline for asset_pipeline false' do
    command = builder.build(
      app_name: 'myapp',
      rails_version: '8.0.0',
      options: { asset_pipeline: false }
    )
    expect(command).to include('--skip-asset-pipeline')
  end

  it 'emits nothing for asset_pipeline true (include with default)' do
    command = builder.build(
      app_name: 'myapp',
      rails_version: '8.0.0',
      options: { asset_pipeline: true }
    )
    expect(command).to eq(%w[rails _8.0.0_ new myapp])
  end

  it 'emits nothing for test minitest (nil flag)' do
    command = builder.build(
      app_name: 'myapp',
      rails_version: '8.1.0',
      options: { test: 'minitest' }
    )
    expect(command).to eq(%w[rails _8.1.0_ new myapp])
  end

  it 'emits --skip-test for test none' do
    command = builder.build(
      app_name: 'myapp',
      rails_version: '8.1.0',
      options: { test: false }
    )
    expect(command).to include('--skip-test')
  end

  it 'emits --skip-bundler-audit when bundler_audit is false' do
    command = builder.build(
      app_name: 'myapp',
      rails_version: '8.1.0',
      options: { bundler_audit: false }
    )
    expect(command).to include('--skip-bundler-audit')
  end
end
