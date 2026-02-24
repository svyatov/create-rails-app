# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CreateRailsApp::Options::Catalog do
  it 'ORDER contains all DEFINITIONS keys' do
    expect(described_class::ORDER).to match_array(described_class::DEFINITIONS.keys)
  end

  it 'fetches a known option definition' do
    definition = described_class.fetch(:database)

    expect(definition[:type]).to eq(:enum)
    expect(definition[:values]).to include('postgresql')
  end

  it 'fetches a skip option definition' do
    definition = described_class.fetch(:hotwire)

    expect(definition[:type]).to eq(:skip)
    expect(definition[:skip_flag]).to eq('--skip-hotwire')
  end

  it 'defines devcontainer as a flag type' do
    definition = described_class.fetch(:devcontainer)
    expect(definition[:type]).to eq(:flag)
    expect(definition[:on]).to eq('--devcontainer')
  end

  it 'defines asset_pipeline as an enum type with propshaft and sprockets' do
    definition = described_class.fetch(:asset_pipeline)
    expect(definition[:type]).to eq(:enum)
    expect(definition[:flag]).to eq('--asset-pipeline')
    expect(definition[:none]).to eq('--skip-asset-pipeline')
    expect(definition[:values]).to eq(%w[propshaft sprockets])
  end

  it 'defines bundler_audit as a skip type' do
    definition = described_class.fetch(:bundler_audit)
    expect(definition[:type]).to eq(:skip)
    expect(definition[:skip_flag]).to eq('--skip-bundler-audit')
  end

  it 'includes mariadb database values' do
    definition = described_class.fetch(:database)
    expect(definition[:values]).to include('mariadb-mysql', 'mariadb-trilogy')
  end

  it 'raises KeyError for unknown option' do
    expect { described_class.fetch(:bogus) }.to raise_error(KeyError)
  end
end
