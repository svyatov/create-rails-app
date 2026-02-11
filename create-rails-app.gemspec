# frozen_string_literal: true

require_relative 'lib/create_rails_app/version'

Gem::Specification.new do |spec|
  spec.name = 'create-rails-app'
  spec.version = CreateRailsApp::VERSION
  spec.authors = ['Leonid Svyatov']
  spec.email = ['leonid@svyatov.com']

  spec.summary = 'Interactive CLI wizard for rails new (coming soon)'
  spec.description = 'Interactive CLI wizard for rails new. ' \
                     'Walks you through every option, saves presets, and remembers your choices. ' \
                     'Work in progress!'
  spec.homepage = 'https://github.com/svyatov/create-rails-app'
  spec.license = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.2')

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/svyatov/create-rails-app'
  spec.metadata['changelog_uri'] = 'https://github.com/svyatov/create-rails-app/blob/main/CHANGELOG.md'
  spec.metadata['documentation_uri'] = 'https://rubydoc.info/gems/create-rails-app'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/svyatov/create-rails-app/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.glob(%w[lib/**/*.rb exe/*]) + %w[LICENSE.txt README.md CHANGELOG.md]
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
end
