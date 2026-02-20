# frozen_string_literal: true

module CreateRailsApp
  # Base error for all create-rails-app failures.
  class Error < StandardError; end

  # Raised when the config file is corrupt or unreadable.
  class ConfigError < Error; end

  # Raised when CLI flags or option values are invalid.
  class ValidationError < Error; end

  # Raised when no supported Rails version can be found or installed.
  class UnsupportedRailsVersionError < Error; end
end
