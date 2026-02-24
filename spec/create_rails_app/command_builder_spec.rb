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
      options: { hotwire: true, test: true }
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

  it 'emits enum skip flag when false' do
    command = builder.build(
      app_name: 'myapp',
      rails_version: '8.1.0',
      options: { javascript: false, css: false }
    )
    expect(command).to include('--skip-javascript', '--skip-css')
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
end
