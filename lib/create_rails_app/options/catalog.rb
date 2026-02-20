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
      DEFINITIONS = {
        # Flags (opt-in)
        api: { type: :flag, on: '--api' },
        # Enums
        database: { type: :enum, flag: '--database', none: '--skip-active-record',
                    values: %w[sqlite3 postgresql mysql trilogy] },
        javascript: { type: :enum, flag: '--javascript', none: '--skip-javascript',
                      values: %w[importmap bun webpack esbuild rollup] },
        css: { type: :enum, flag: '--css', none: '--skip-css',
               values: %w[tailwind bootstrap bulma postcss sass] },
        asset_pipeline: { type: :enum, flag: '--asset-pipeline', none: '--skip-asset-pipeline',
                          values: %w[propshaft sprockets] },
        # Skip (included by default, --skip-X to exclude)
        active_record: { type: :skip, skip_flag: '--skip-active-record' },
        action_mailer: { type: :skip, skip_flag: '--skip-action-mailer' },
        action_mailbox: { type: :skip, skip_flag: '--skip-action-mailbox' },
        action_text: { type: :skip, skip_flag: '--skip-action-text' },
        active_job: { type: :skip, skip_flag: '--skip-active-job' },
        active_storage: { type: :skip, skip_flag: '--skip-active-storage' },
        action_cable: { type: :skip, skip_flag: '--skip-action-cable' },
        hotwire: { type: :skip, skip_flag: '--skip-hotwire' },
        jbuilder: { type: :skip, skip_flag: '--skip-jbuilder' },
        test: { type: :skip, skip_flag: '--skip-test' },
        system_test: { type: :skip, skip_flag: '--skip-system-test' },
        brakeman: { type: :skip, skip_flag: '--skip-brakeman' },
        rubocop: { type: :skip, skip_flag: '--skip-rubocop' },
        ci: { type: :skip, skip_flag: '--skip-ci' },
        docker: { type: :skip, skip_flag: '--skip-docker' },
        kamal: { type: :skip, skip_flag: '--skip-kamal' },
        thruster: { type: :skip, skip_flag: '--skip-thruster' },
        solid: { type: :skip, skip_flag: '--skip-solid' },
        devcontainer: { type: :skip, skip_flag: '--skip-devcontainer' },
        bootsnap: { type: :skip, skip_flag: '--skip-bootsnap' },
        git: { type: :skip, skip_flag: '--skip-git' },
        bundle: { type: :skip, skip_flag: '--skip-bundle' }
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
