# frozen_string_literal: true

module CreateRailsApp
  module Compatibility
    # Static lookup table mapping Rails version ranges to the +rails new+
    # options each range supports.
    #
    # This is the single source of truth for what each Rails version
    # can do. The wizard, validator, and builder all consult it.
    #
    # @example Look up the entry for a specific Rails version
    #   entry = Matrix.for('8.0.1')
    #   entry.supports_option?(:kamal)  #=> true
    class Matrix
      # A single row in the compatibility table.
      #
      # @!attribute [r] requirement
      #   @return [Gem::Requirement] Rails version range this entry covers
      # @!attribute [r] supported_options
      #   @return [Hash{Symbol => Array<String>, nil}] option keys to allowed
      #     values (+nil+ means any boolean/skip value is accepted)
      Entry = Struct.new(:requirement, :supported_options, keyword_init: true) do
        # @param rails_version [Gem::Version] version to test
        # @return [Boolean]
        def match?(rails_version)
          requirement.satisfied_by?(rails_version)
        end

        # @param option_key [Symbol, String]
        # @return [Boolean]
        def supports_option?(option_key)
          supported_options.key?(option_key.to_sym)
        end

        # @param option_key [Symbol, String]
        # @return [Array<String>, nil] allowed values, or nil for skips/flags
        def allowed_values(option_key)
          supported_options.fetch(option_key.to_sym)
        end
      end

      # Supported Rails series for version detection and installation.
      #
      # @return [Array<String>]
      SUPPORTED_SERIES = %w[7.2 8.0 8.1].freeze

      # Options shared across all supported Rails versions.
      COMMON_OPTIONS = {
        api: nil,
        database: %w[sqlite3 postgresql mysql trilogy],
        javascript: %w[importmap bun webpack esbuild rollup],
        css: %w[tailwind bootstrap bulma postcss sass],
        asset_pipeline: %w[propshaft sprockets],
        active_record: nil,
        action_mailer: nil,
        action_mailbox: nil,
        action_text: nil,
        active_job: nil,
        active_storage: nil,
        action_cable: nil,
        hotwire: nil,
        jbuilder: nil,
        test: nil,
        system_test: nil,
        rubocop: nil,
        docker: nil,
        bootsnap: nil,
        git: nil,
        bundle: nil
      }.freeze

      # Options only available in Rails 8.0+.
      RAILS_8_OPTIONS = {
        brakeman: nil,
        ci: nil,
        kamal: nil,
        thruster: nil,
        solid: nil,
        devcontainer: nil
      }.freeze

      # @return [Array<Entry>] all known Rails compatibility entries
      TABLE = [
        Entry.new(
          requirement: Gem::Requirement.new('~> 7.2.0'),
          supported_options: COMMON_OPTIONS.dup.freeze
        ),
        Entry.new(
          requirement: Gem::Requirement.new('~> 8.0.0'),
          supported_options: COMMON_OPTIONS.merge(RAILS_8_OPTIONS).freeze
        ),
        Entry.new(
          requirement: Gem::Requirement.new('~> 8.1.0'),
          supported_options: COMMON_OPTIONS.merge(RAILS_8_OPTIONS).freeze
        )
      ].freeze

      # Returns human-readable version range strings for all entries.
      #
      # @return [Array<String>]
      def self.supported_ranges
        TABLE.map { |entry| entry.requirement.requirements.map(&:join).join(', ') }
      end

      # Finds the compatibility entry for the given Rails version.
      #
      # @param rails_version [Gem::Version, String] the Rails version
      # @return [Entry]
      # @raise [UnsupportedRailsVersionError] if no entry matches
      def self.for(rails_version)
        version = Gem::Version.new(rails_version.to_s)
        entry = TABLE.find { |candidate| candidate.match?(version) }
        return entry if entry

        message = "Unsupported Rails version: #{version}. "
        message += "Supported ranges: #{supported_ranges.join(' | ')}"
        raise UnsupportedRailsVersionError, message
      end
    end
  end
end
