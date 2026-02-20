# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CreateRailsApp::Detection::Runtime do
  it 'returns ruby and rubygems versions' do
    versions = described_class.new.detect!

    expect(versions.ruby).to be_a(Gem::Version)
    expect(versions.rubygems).to be_a(Gem::Version)
  end
end
