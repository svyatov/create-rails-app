# frozen_string_literal: true

require_relative 'create_rails_app/version'
require_relative 'create_rails_app/error'
require_relative 'create_rails_app/detection/runtime'
require_relative 'create_rails_app/detection/rails_versions'
require_relative 'create_rails_app/options/catalog'
require_relative 'create_rails_app/compatibility/matrix'
require_relative 'create_rails_app/options/validator'
require_relative 'create_rails_app/command_builder'
require_relative 'create_rails_app/config/store'
require_relative 'create_rails_app/runner'
require_relative 'create_rails_app/ui/palette'
require_relative 'create_rails_app/ui/prompter'
require_relative 'create_rails_app/wizard'
require_relative 'create_rails_app/cli'

# Interactive TUI wizard for +rails new+.
#
# Detects installed Rails versions, shows version-aware options
# via a static compatibility matrix, and builds the correct +rails new+
# command. Config (presets, last-used options) is stored in
# +~/.config/create-rails-app/config.yml+.
#
# @see CreateRailsApp::CLI Entry point
# @see CreateRailsApp::Compatibility::Matrix Rails version compatibility
module CreateRailsApp
end
