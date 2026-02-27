# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'

  if ENV['CI']
    require 'simplecov_json_formatter'
    SimpleCov.formatter = SimpleCov::Formatter::JSONFormatter
  end

  SimpleCov.start do
    enable_coverage :branch
    add_filter '/spec/'
  end
end

require 'create_rails_app'

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'

  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
