# frozen_string_literal: true

module CreateRailsApp
  module Options
    # Registry of every +rails new+ option create-rails-app knows about.
    #
    # Each entry in {DEFINITIONS} describes the option's type and CLI flags.
    # {ORDER} controls the sequence in which the wizard presents options.
    #
    # @see Options::Validator
    # @see Wizard
    module Catalog
      # Option definitions keyed by symbolic name.
      #
      # Types:
      # - +:flag+  — opt-in; emits +--flag+ when true, nothing when false
      # - +:enum+  — emits +--flag=value+; +:none+ flag emits +--skip-flag+
      # - +:skip+  — opt-out; emits nothing when true (include), +--skip-X+ when false (exclude)
      #
      # @return [Hash{Symbol => Hash}]
      # Database adapters shared across all Rails versions.
      BASE_DATABASE_VALUES = %w[sqlite3 postgresql mysql trilogy].freeze

      # Database adapters added in Rails 8.0+.
      MARIADB_DATABASE_VALUES = %w[mariadb-mysql mariadb-trilogy].freeze

      DEFINITIONS = {
        # Flags (opt-in)
        api: { type: :flag, on: '--api' }.freeze,
        # Enums
        database: { type: :enum, flag: '--database',
                    values: (BASE_DATABASE_VALUES + MARIADB_DATABASE_VALUES).freeze }.freeze,
        javascript: { type: :enum, flag: '--javascript', none: '--skip-javascript',
                      values: %w[importmap bun webpack esbuild rollup].freeze }.freeze,
        css: { type: :enum, flag: '--css', none: '--skip-css',
               values: %w[tailwind bootstrap bulma postcss sass].freeze,
               rails_default: 'none' }.freeze,
        asset_pipeline: { type: :enum, flag: '--asset-pipeline', none: '--skip-asset-pipeline',
                          values: %w[sprockets propshaft].freeze }.freeze,
        # Skip (included by default, --skip-X to exclude)
        active_record: { type: :skip, skip_flag: '--skip-active-record' }.freeze,
        action_mailer: { type: :skip, skip_flag: '--skip-action-mailer' }.freeze,
        action_mailbox: { type: :skip, skip_flag: '--skip-action-mailbox' }.freeze,
        action_text: { type: :skip, skip_flag: '--skip-action-text' }.freeze,
        active_job: { type: :skip, skip_flag: '--skip-active-job' }.freeze,
        active_storage: { type: :skip, skip_flag: '--skip-active-storage' }.freeze,
        action_cable: { type: :skip, skip_flag: '--skip-action-cable' }.freeze,
        hotwire: { type: :skip, skip_flag: '--skip-hotwire' }.freeze,
        jbuilder: { type: :skip, skip_flag: '--skip-jbuilder' }.freeze,
        test: { type: :skip, skip_flag: '--skip-test' }.freeze,
        system_test: { type: :skip, skip_flag: '--skip-system-test' }.freeze,
        brakeman: { type: :skip, skip_flag: '--skip-brakeman' }.freeze,
        bundler_audit: { type: :skip, skip_flag: '--skip-bundler-audit' }.freeze,
        rubocop: { type: :skip, skip_flag: '--skip-rubocop' }.freeze,
        ci: { type: :skip, skip_flag: '--skip-ci' }.freeze,
        docker: { type: :skip, skip_flag: '--skip-docker' }.freeze,
        kamal: { type: :skip, skip_flag: '--skip-kamal' }.freeze,
        thruster: { type: :skip, skip_flag: '--skip-thruster' }.freeze,
        solid: { type: :skip, skip_flag: '--skip-solid' }.freeze,
        devcontainer: { type: :flag, on: '--devcontainer' }.freeze,
        bootsnap: { type: :skip, skip_flag: '--skip-bootsnap' }.freeze,
        git: { type: :skip, skip_flag: '--skip-git' }.freeze,
        bundle: { type: :skip, skip_flag: '--skip-bundle' }.freeze
      }.freeze

      # Wizard step order — matches the sequence users see.
      #
      # @return [Array<Symbol>]
      ORDER = %i[
        api
        active_record
        database
        javascript
        css
        asset_pipeline
        hotwire
        jbuilder
        action_mailer
        action_mailbox
        action_text
        active_job
        active_storage
        action_cable
        test
        system_test
        brakeman
        bundler_audit
        rubocop
        ci
        docker
        kamal
        thruster
        solid
        devcontainer
        bootsnap
        git
        bundle
      ].freeze

      # Fetches the definition for a given option key.
      #
      # @param key [Symbol, String]
      # @return [Hash] the option definition
      # @raise [KeyError] if the key is unknown
      def self.fetch(key)
        DEFINITIONS.fetch(key.to_sym)
      end
    end
  end
end
