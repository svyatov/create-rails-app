# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'exe/create-rails-app' do
  let(:exe_path) { File.expand_path('../../../exe/create-rails-app', __dir__) }

  it 'prints version with --version' do
    output = `bundle exec ruby #{exe_path} --version 2>&1`
    expect(output.strip).to eq(CreateRailsApp::VERSION)
    expect($CHILD_STATUS.exitstatus).to eq(0)
  end

  it 'returns non-zero for invalid flags' do
    output = `bundle exec ruby #{exe_path} --unknown-flag 2>&1`
    expect(output).to include('invalid option')
    expect($CHILD_STATUS.exitstatus).to eq(1)
  end
end
