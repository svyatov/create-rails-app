# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CreateRailsApp::Detection::Runtime do
  subject(:info) { described_class.new.detect }

  it 'returns a RuntimeInfo with Gem::Version values' do
    expect(info).to be_a(CreateRailsApp::Detection::RuntimeInfo)
    expect(info.ruby).to be_a(Gem::Version)
    expect(info.rubygems).to be_a(Gem::Version)
    expect(info.ruby).to eq(Gem::Version.new(RUBY_VERSION))
    expect(info.rubygems).to eq(Gem::Version.new(Gem::VERSION))
  end
end
