# frozen_string_literal: true

ENV['RUBOCOP_CACHE_ROOT'] = File.expand_path('.rubocop_cache', __dir__)

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

require 'rubocop/rake_task'

RuboCop::RakeTask.new do |task|
  task.options = %w[--format progress --parallel]
end

Rake::Task['release:rubygem_push'].enhance(['fetch_otp'])

task :fetch_otp do
  next if ENV['GEM_HOST_OTP_CODE']&.match?(/\A\d{6}\z/)

  abort 'OTP fetch requires the 1Password CLI (op). Install it or set GEM_HOST_OTP_CODE manually.' \
    unless system('op', '--version', out: File::NULL, err: File::NULL)

  ENV['GEM_HOST_OTP_CODE'] = `op item get "RubyGems" --otp`.strip
end

task default: %i[spec rubocop]
