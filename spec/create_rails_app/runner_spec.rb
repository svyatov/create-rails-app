# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe CreateRailsApp::Runner do
  it 'prints dry-run command' do
    out = StringIO.new
    described_class.new(out: out).run!(%w[rails _8.1.0_ new myapp --api], dry_run: true)
    expect(out.string).to include('rails _8.1.0_ new myapp --api')
  end

  it 'raises when command execution fails' do
    runner = described_class.new(out: StringIO.new, system_runner: ->(*) { false })

    expect do
      runner.run!(%w[rails _8.1.0_ new myapp])
    end.to raise_error(CreateRailsApp::Error, /Command failed/)
  end

  it 'returns true on successful execution' do
    status = instance_double(Process::Status, success?: true)
    runner = described_class.new(out: StringIO.new, system_runner: ->(*) { status })

    expect(runner.run!(%w[rails _8.1.0_ new myapp])).to be(true)
  end

  it 'raises when system_runner returns truthy non-Status value' do
    runner = described_class.new(out: StringIO.new, system_runner: ->(*) { true })

    expect do
      runner.run!(%w[rails new myapp])
    end.to raise_error(CreateRailsApp::Error, /Command failed/)
  end

  it 'includes exitstatus in error message' do
    status = instance_double(Process::Status, success?: false, exitstatus: 42)
    runner = described_class.new(out: StringIO.new, system_runner: ->(*) { status })

    expect do
      runner.run!(%w[rails new myapp])
    end.to raise_error(CreateRailsApp::Error, /exit 42/)
  end

  it 'shell-escapes dry-run output for arguments with spaces' do
    out = StringIO.new
    described_class.new(out: out).run!(['rails', 'new', 'my app'], dry_run: true)
    expect(out.string.strip).to eq('rails new my\\ app')
  end
end
