# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CreateRailsApp::Detection::RailsVersions do
  it 'parses installed versions from gem list output' do
    detector = described_class.new
    allow(IO).to receive(:popen).and_return("rails (8.1.2, 8.0.7, 7.2.3)\n")

    result = detector.detect

    expect(result['8.1']).to eq('8.1.2')
    expect(result['8.0']).to eq('8.0.7')
    expect(result['7.2']).to eq('7.2.3')
  end

  it 'returns only supported series' do
    detector = described_class.new
    allow(IO).to receive(:popen).and_return("rails (6.1.7, 8.0.3)\n")

    result = detector.detect

    expect(result).to eq('8.0' => '8.0.3')
    expect(result).not_to have_key('6.1')
  end

  it 'returns empty hash when no rails installed' do
    detector = described_class.new
    allow(IO).to receive(:popen).and_return('')

    expect(detector.detect).to eq({})
  end

  it 'returns empty hash when gem command not found' do
    detector = described_class.new(gem_command: 'nonexistent_gem_binary')
    allow(IO).to receive(:popen).and_raise(Errno::ENOENT)

    expect(detector.detect).to eq({})
  end

  it 'picks latest patch version per series' do
    detector = described_class.new
    allow(IO).to receive(:popen).and_return("rails (8.0.1, 8.0.5, 8.0.3)\n")

    result = detector.detect

    expect(result['8.0']).to eq('8.0.5')
  end

  it 'returns empty hash on permission error' do
    detector = described_class.new
    allow(IO).to receive(:popen).and_raise(Errno::EACCES)

    expect(detector.detect).to eq({})
  end

  it 'returns empty hash on non-zero exit from gem list' do
    detector = described_class.new
    allow(IO).to receive(:popen) do |*_args, **_kwargs, &_block|
      `exit 1` # sets $CHILD_STATUS to a failed status
      "ERROR: something went wrong\n"
    end

    expect(detector.detect).to eq({})
  end
end
