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
      Entry = Struct.new(:requirement, :supported_options) do
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
          supported_options[option_key.to_sym]
        end
      end

      # Supported Rails series for version detection and installation.
      #
      # @return [Array<String>]
      SUPPORTED_SERIES = %w[7.2 8.0 8.1].freeze

      # Options shared across all supported Rails versions.
      # Enum values are derived from Catalog to prevent drift.
      COMMON_OPTIONS = {
        api: nil,
        database: Options::Catalog::BASE_DATABASE_VALUES,
        javascript: Options::Catalog::DEFINITIONS[:javascript][:values],
        css: Options::Catalog::DEFINITIONS[:css][:values],
        asset_pipeline: Options::Catalog::DEFINITIONS[:asset_pipeline][:values],
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
        brakeman: nil,
        rubocop: nil,
        ci: nil,
        docker: nil,
        devcontainer: nil,
        bootsnap: nil,
        dev_gems: nil,
        keeps: nil,
        decrypted_diffs: nil,
        git: nil,
        bundle: nil
      }.freeze

      # Options added or changed in Rails 8.0+.
      RAILS_8_OPTIONS = {
        kamal: nil,
        thruster: nil,
        solid: nil,
        database: Options::Catalog::DEFINITIONS[:database][:values],
        asset_pipeline: nil
      }.freeze

      # Options added in Rails 8.1+.
      RAILS_81_OPTIONS = {
        bundler_audit: nil
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
          supported_options: COMMON_OPTIONS.merge(RAILS_8_OPTIONS).merge(RAILS_81_OPTIONS).freeze
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
