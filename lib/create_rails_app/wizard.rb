# frozen_string_literal: true

module CreateRailsApp
  # Step-by-step interactive prompt loop for choosing +rails new+ options.
  #
  # Walks through each supported option in {Options::Catalog::ORDER},
  # presenting only the options supported by the detected Rails version.
  # Supports back-navigation via +Ctrl+B+ and smart filtering via {SKIP_RULES}.
  #
  # @see CLI#run_interactive_wizard!
  class Wizard
    # Sentinel returned by the prompter when the user presses Ctrl+B.
    BACK = Object.new.tap { |o| o.define_singleton_method(:inspect) { '#<BACK>' } }.freeze

    # Human-readable labels for each option key.
    #
    # @return [Hash{Symbol => String}]
    LABELS = {
      api: 'API-only mode',
      active_record: 'Active Record (ORM)',
      database: 'Database',
      javascript: 'JavaScript approach',
      css: 'CSS framework',
      asset_pipeline: 'Asset pipeline',
      hotwire: 'Hotwire (Turbo + Stimulus)',
      jbuilder: 'Jbuilder (JSON templates)',
      action_mailer: 'Action Mailer',
      action_mailbox: 'Action Mailbox',
      action_text: 'Action Text (rich text)',
      active_job: 'Active Job',
      active_storage: 'Active Storage (file uploads)',
      action_cable: 'Action Cable (WebSockets)',
      test: 'Test framework',
      system_test: 'System tests',
      brakeman: 'Brakeman (security scanner)',
      bundler_audit: 'Bundler Audit (dependency checker)',
      rubocop: 'RuboCop (linter)',
      ci: 'CI files',
      docker: 'Dockerfile',
      kamal: 'Kamal (deployment)',
      thruster: 'Thruster (HTTP/2 proxy)',
      solid: 'Solid (Cache/Queue/Cable)',
      devcontainer: 'Dev Container',
      bootsnap: 'Bootsnap (boot speedup)',
      git: 'Initialize git',
      bundle: 'Run bundle install'
    }.freeze

    # Short explanations shown below each wizard step.
    #
    # @return [Hash{Symbol => String}]
    HELP_TEXT = {
      api: 'Generates a slimmed-down app optimized for API backends.',
      active_record: 'Database ORM layer. Skipping also skips the database choice.',
      database: 'Which database adapter to configure.',
      javascript: 'How JavaScript is managed in the asset pipeline.',
      css: 'Which CSS framework to pre-install.',
      asset_pipeline: 'Which asset pipeline to use for JS/CSS bundling.',
      hotwire: 'Turbo + Stimulus for SPA-like behavior over HTML.',
      jbuilder: 'DSL for building JSON views.',
      action_mailer: 'Framework for sending emails.',
      action_mailbox: 'Routes inbound emails to controller-like mailboxes.',
      action_text: 'Rich text content and editing with Trix.',
      active_job: 'Framework for declaring and running background jobs.',
      active_storage: 'Upload files to cloud services like S3 or GCS.',
      action_cable: 'WebSocket framework for real-time features.',
      test: 'Generates test directory and helpers.',
      system_test: 'Browser-based integration tests via Capybara.',
      brakeman: 'Static analysis for security vulnerabilities.',
      bundler_audit: 'Checks dependencies for known vulnerabilities.',
      rubocop: 'Ruby style and lint checking.',
      ci: 'Generates CI workflow configuration.',
      docker: 'Generates Dockerfile for containerized deployment.',
      kamal: 'Generates Kamal deploy configuration.',
      thruster: 'HTTP/2 proxy with asset caching and X-Sendfile.',
      solid: 'Solid Cache, Solid Queue, and Solid Cable adapters.',
      devcontainer: 'Generates VS Code dev container configuration.',
      bootsnap: 'Speeds up boot times with caching.',
      git: 'Initializes a git repository for the new app.',
      bundle: 'Runs bundle install after generating the app.'
    }.freeze

    # Per-choice hints displayed next to enum choices.
    #
    # @return [Hash{Symbol => Hash{String => String}}]
    CHOICE_HELP = {
      database: {
        'sqlite3' => 'simple file-based, great for development',
        'postgresql' => 'full-featured, most popular for production',
        'mysql' => 'widely used relational database',
        'trilogy' => 'modern MySQL-compatible client',
        'mariadb-mysql' => 'MariaDB with mysql2 adapter',
        'mariadb-trilogy' => 'MariaDB with Trilogy adapter'
      },
      javascript: {
        'importmap' => 'no bundler, uses browser-native import maps',
        'bun' => 'fast all-in-one JS runtime and bundler',
        'webpack' => 'established full-featured bundler',
        'esbuild' => 'extremely fast JS bundler',
        'rollup' => 'ES module-focused bundler',
        'none' => 'no JavaScript setup'
      },
      asset_pipeline: {
        'propshaft' => 'modern, lightweight asset pipeline',
        'sprockets' => 'classic asset pipeline with preprocessing',
        'none' => 'no asset pipeline'
      },
      css: {
        'tailwind' => 'utility-first CSS framework',
        'bootstrap' => 'popular component-based framework',
        'bulma' => 'modern CSS-only framework',
        'postcss' => 'CSS transformations via plugins',
        'sass' => 'CSS with variables, nesting, and mixins',
        'none' => 'no CSS framework'
      }
    }.freeze

    # Rules that determine when a wizard step should be silently skipped.
    # Each lambda receives the current values hash and returns true to skip.
    #
    # @return [Hash{Symbol => Proc}]
    SKIP_RULES = {
      database: ->(values) { values[:active_record] == false },
      javascript: ->(values) { values[:api] == true },
      css: ->(values) { values[:api] == true },
      asset_pipeline: ->(values) { values[:api] == true },
      hotwire: ->(values) { values[:api] == true },
      jbuilder: ->(values) { values[:api] == true },
      action_mailbox: ->(values) { values[:active_record] == false },
      action_text: ->(values) { values[:api] == true || values[:active_record] == false },
      active_storage: ->(values) { values[:active_record] == false },
      system_test: ->(values) { values[:test] == false || values[:api] == true }
    }.freeze

    # @param compatibility_entry [Compatibility::Matrix::Entry]
    # @param defaults [Hash{Symbol => Object}] initial default values (e.g. last-used)
    # @param prompter [UI::Prompter]
    def initialize(compatibility_entry:, defaults:, prompter:)
      @compatibility_entry = compatibility_entry
      @prompter = prompter
      @values = sanitize_defaults(defaults)
      @stashed = {}
    end

    # Runs the wizard and returns the selected options.
    #
    # @return [Hash{Symbol => Object}]
    def run
      keys = Options::Catalog::ORDER.select { |key| @compatibility_entry.supports_option?(key) }
      index = 0
      while index < keys.length
        key = keys[index]

        if skip_step?(key)
          @stashed[key] = @values.delete(key) if @values.key?(key)
          index += 1
          next
        end

        @values[key] = @stashed.delete(key) if @stashed.key?(key) && !@values.key?(key)

        answer = ask_for(key, index:, total: keys.length)
        case answer
        when BACK
          index = find_previous_unskipped(keys, index)
        else
          assign_value(key, answer)
          index += 1
        end
      end
      @values.dup
    end

    private

    # @param key [Symbol]
    # @return [Boolean]
    def skip_step?(key)
      rule = SKIP_RULES[key]
      rule&.call(@values)
    end

    # Finds the previous unskipped step index.
    #
    # @param keys [Array<Symbol>]
    # @param current_index [Integer]
    # @return [Integer]
    def find_previous_unskipped(keys, current_index)
      i = current_index - 1
      # i.positive? (not i >= 0) stops the loop at i==0 so we can check
      # the first step explicitly below.  If every preceding step is
      # skipped, we stay at current_index (nowhere to go back to).
      i -= 1 while i.positive? && skip_step?(keys[i])
      return current_index if i >= 0 && skip_step?(keys[i])

      [i, 0].max
    end

    # @param key [Symbol]
    # @param index [Integer]
    # @param total [Integer]
    # @return [Object] user answer or {BACK}
    def ask_for(key, index:, total:)
      definition = Options::Catalog.fetch(key)
      label = LABELS.fetch(key)
      question = render_question(index: index, total: total, key: key, label: label)
      case definition[:type]
      when :skip
        ask_skip(question, key)
      when :flag
        ask_flag(question, key)
      when :enum
        # When the Matrix provides nil (no enum values), the option is a
        # simple include/skip for this Rails version (e.g. asset_pipeline in 8.0+).
        if @compatibility_entry.allowed_values(key)
          ask_enum(question, key, definition)
        else
          ask_skip(question, key)
        end
      else
        raise Error, "Unknown option type for #{key}"
      end
    end

    # @param question [String]
    # @param key [Symbol]
    # @return [true, false, BACK]
    def ask_skip(question, key)
      choices = %w[include skip]
      current = @values[key]
      selected = current == false ? 'skip' : 'include'
      answer = choose_with_default_marker(question, key:, choices:, rails_default: 'include', selected:)
      return BACK if answer == BACK
      return false if answer == 'skip'

      true
    end

    # @param question [String]
    # @param key [Symbol]
    # @return [true, nil, BACK]
    def ask_flag(question, key)
      choices = %w[yes no]
      current = @values[key]
      selected = current == true ? 'yes' : 'no'
      answer = choose_with_default_marker(question, key:, choices:, rails_default: 'no', selected:)
      return BACK if answer == BACK
      return true if answer == 'yes'

      nil
    end

    # @param question [String]
    # @param key [Symbol]
    # @param definition [Hash]
    # @return [String, false, BACK]
    def ask_enum(question, key, definition)
      choices = @compatibility_entry.allowed_values(key).dup
      choices << 'none' if definition[:none]
      current = @values[key]
      selected = enum_selected_choice(current, choices)
      rails_default = definition[:rails_default] || choices.first
      answer = choose_with_default_marker(question, key:, choices:, rails_default:, selected:)
      return BACK if answer == BACK
      return false if answer == 'none'

      answer
    end

    # @param key [Symbol]
    # @param value [Object]
    # @return [void]
    def assign_value(key, value)
      if value.nil?
        @values.delete(key)
      else
        @values[key] = value
      end
    end

    # Filters defaults to only supported options.
    #
    # @param hash [Hash]
    # @return [Hash{Symbol => Object}]
    def sanitize_defaults(hash)
      hash.transform_keys(&:to_sym)
          .select { |key, _| @compatibility_entry.supports_option?(key) }
    end

    # Resolves which enum choice to pre-select based on the user's last pick.
    #
    # @param current [Object]
    # @param choices [Array<String>]
    # @return [String]
    def enum_selected_choice(current, choices)
      return 'none' if current == false && choices.include?('none')
      return choices.first if current == true
      return current if current.is_a?(String) && choices.include?(current)

      choices.first
    end

    # Presents a choice list with the Rails default labeled and the user's
    # last pick reordered first (pre-selected).
    #
    # @param question [String]
    # @param key [Symbol]
    # @param choices [Array<String>]
    # @param rails_default [String] the true Rails default (labeled "(default)")
    # @param selected [String] the user's last pick (reordered first)
    # @return [String] the raw choice value, or {BACK}
    def choose_with_default_marker(question, key:, choices:, rails_default:, selected:)
      actual_selected = choices.include?(selected) ? selected : choices.first
      rendered_pairs = choices.map do |choice|
        [render_choice_label(key, choice, rails_default: rails_default), choice]
      end
      rendered = rendered_pairs.map(&:first)
      selected_label = rendered_pairs.find { |_, raw| raw == actual_selected }&.first || rendered.first
      answer = @prompter.choose(question, options: rendered, default: selected_label)
      return BACK if answer == BACK

      rendered_index = rendered.index(answer)
      return choices[rendered_index] if rendered_index

      actual_selected
    end

    # @param index [Integer]
    # @param total [Integer]
    # @param key [Symbol]
    # @param label [String]
    # @return [String]
    def render_question(index:, total:, key:, label:)
      step = format('%<current>02d/%<total>02d', current: index + 1, total: total)
      "{{cyan:#{step}}} {{bold:#{label}}} - #{HELP_TEXT.fetch(key)}"
    end

    # @param key [Symbol]
    # @param choice [String]
    # @param default_choice [String]
    # @return [String]
    def render_choice_label(key, choice, rails_default:)
      label = choice
      hint = CHOICE_HELP.dig(key, choice)
      label = "#{label} - #{hint}" if hint
      label = "#{label} (default)" if choice == rails_default
      label
    end
  end
end
