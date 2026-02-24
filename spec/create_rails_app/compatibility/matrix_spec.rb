# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CreateRailsApp::Compatibility::Matrix do
  describe '.for' do
    it 'returns a match for Rails 8.1 with bundler_audit' do
      entry = described_class.for('8.1.0')
      expect(entry.supports_option?(:kamal)).to be(true)
      expect(entry.supports_option?(:solid)).to be(true)
      expect(entry.supports_option?(:devcontainer)).to be(true)
      expect(entry.supports_option?(:bundler_audit)).to be(true)
    end

    it 'returns a match for Rails 8.0 without bundler_audit' do
      entry = described_class.for('8.0.1')
      expect(entry.supports_option?(:kamal)).to be(true)
      expect(entry.supports_option?(:brakeman)).to be(true)
      expect(entry.supports_option?(:ci)).to be(true)
      expect(entry.supports_option?(:bundler_audit)).to be(false)
    end

    it 'returns a match for Rails 7.2 with brakeman/ci/devcontainer but without 8.0+ options' do
      entry = described_class.for('7.2.3')
      expect(entry.supports_option?(:database)).to be(true)
      expect(entry.supports_option?(:hotwire)).to be(true)
      expect(entry.supports_option?(:brakeman)).to be(true)
      expect(entry.supports_option?(:ci)).to be(true)
      expect(entry.supports_option?(:devcontainer)).to be(true)
      expect(entry.supports_option?(:kamal)).to be(false)
      expect(entry.supports_option?(:solid)).to be(false)
      expect(entry.supports_option?(:thruster)).to be(false)
      expect(entry.supports_option?(:bundler_audit)).to be(false)
    end

    it 'does not support mariadb databases for Rails 7.2' do
      entry = described_class.for('7.2.3')
      expect(entry.allowed_values(:database)).not_to include('mariadb-mysql')
      expect(entry.allowed_values(:database)).not_to include('mariadb-trilogy')
    end

    it 'supports mariadb databases for Rails 8.0+' do
      entry = described_class.for('8.0.0')
      expect(entry.allowed_values(:database)).to include('mariadb-mysql', 'mariadb-trilogy')
    end

    it 'provides asset_pipeline enum values for Rails 7.2' do
      entry = described_class.for('7.2.0')
      expect(entry.allowed_values(:asset_pipeline)).to eq(%w[propshaft sprockets])
    end

    it 'provides asset_pipeline as skip (nil) for Rails 8.0+' do
      entry = described_class.for('8.0.0')
      expect(entry.allowed_values(:asset_pipeline)).to be_nil
    end

    it 'provides test enum values across all versions' do
      %w[7.2.0 8.0.0 8.1.0].each do |version|
        entry = described_class.for(version)
        expect(entry.allowed_values(:test)).to eq(%w[minitest])
      end
    end

    it 'derives database values from Catalog constants' do
      entry = described_class.for('7.2.0')
      expect(entry.allowed_values(:database)).to eq(
        CreateRailsApp::Options::Catalog::BASE_DATABASE_VALUES
      )

      entry = described_class.for('8.0.0')
      expect(entry.allowed_values(:database)).to eq(
        CreateRailsApp::Options::Catalog::DEFINITIONS[:database][:values]
      )
    end

    it 'raises for unsupported versions' do
      expect { described_class.for('6.1.0') }
        .to raise_error(CreateRailsApp::UnsupportedRailsVersionError, /Supported ranges:/)
    end

    it 'raises for version below minimum' do
      expect { described_class.for('7.1.0') }
        .to raise_error(CreateRailsApp::UnsupportedRailsVersionError)
    end
  end

  describe '.supported_ranges' do
    it 'returns an array of range strings' do
      ranges = described_class.supported_ranges
      expect(ranges).to be_an(Array)
      expect(ranges.length).to eq(described_class::TABLE.length)
    end
  end

  describe CreateRailsApp::Compatibility::Matrix::Entry do
    it 'returns nil for skip allowed_values' do
      entry = described_class.new(
        requirement: Gem::Requirement.new('>= 0'),
        supported_options: { hotwire: nil }
      )
      expect(entry.allowed_values(:hotwire)).to be_nil
    end

    it 'returns enum values for database' do
      entry = CreateRailsApp::Compatibility::Matrix.for('8.0.0')
      expect(entry.allowed_values(:database)).to include('postgresql', 'mysql')
    end
  end
end
