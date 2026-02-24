# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CreateRailsApp::Detection::RailsVersions do
  def stub_gem_list(output, success: true)
    status = instance_double(Process::Status, success?: success)
    allow(Open3).to receive(:capture2e).and_return([output, status])
  end

  it 'parses installed versions from gem list output' do
    detector = described_class.new
    stub_gem_list("rails (8.1.2, 8.0.7, 7.2.3)\n")

    result = detector.detect

    expect(result['8.1']).to eq('8.1.2')
    expect(result['8.0']).to eq('8.0.7')
    expect(result['7.2']).to eq('7.2.3')
  end

  it 'returns only supported series' do
    detector = described_class.new
    stub_gem_list("rails (6.1.7, 8.0.3)\n")

    result = detector.detect

    expect(result).to eq('8.0' => '8.0.3')
    expect(result).not_to have_key('6.1')
  end

  it 'returns empty hash when no rails installed' do
    detector = described_class.new
    stub_gem_list('')

    expect(detector.detect).to eq({})
  end

  it 'returns empty hash when gem command not found' do
    detector = described_class.new(gem_command: 'nonexistent_gem_binary')
    allow(Open3).to receive(:capture2e).and_raise(Errno::ENOENT)

    expect(detector.detect).to eq({})
  end

  it 'picks latest patch version per series' do
    detector = described_class.new
    stub_gem_list("rails (8.0.1, 8.0.5, 8.0.3)\n")

    result = detector.detect

    expect(result['8.0']).to eq('8.0.5')
  end

  it 'returns empty hash on permission error' do
    detector = described_class.new
    allow(Open3).to receive(:capture2e).and_raise(Errno::EACCES)

    expect(detector.detect).to eq({})
  end

  it 'only matches rails gem line, not railties or other gems' do
    detector = described_class.new
    stub_gem_list("railties (8.1.2, 8.0.7)\nrails (8.0.5)\nrails-html-sanitizer (1.6.0)\n")

    result = detector.detect

    expect(result['8.0']).to eq('8.0.5')
    expect(result).not_to have_key('8.1')
  end

  it 'returns empty hash on non-zero exit from gem list' do
    detector = described_class.new
    stub_gem_list("ERROR: something went wrong\n", success: false)

    expect(detector.detect).to eq({})
  end
end
