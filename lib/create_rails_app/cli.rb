# frozen_string_literal: true

require 'optparse'

module CreateRailsApp
  # Main entry point that orchestrates the entire create-rails-app flow.
  #
  # Parses CLI flags, detects installed Rails versions, runs the interactive
  # wizard (or loads a preset), builds the +rails new+ command, and executes it.
  # All collaborators are injected via constructor for testability.
  #
  # @example Run from the command line
  #   CreateRailsApp::CLI.start(ARGV)
  class CLI
    # Holds the resolved Rails version info and whether installation is needed.
    VersionChoice = Struct.new(:version, :series, :needs_install, keyword_init: true)

    # Constructs and runs a CLI instance with the given arguments.
    #
    # @param argv [Array<String>] command-line arguments
    # @param out [IO] standard output stream
    # @param err [IO] standard error stream
    # @param store [Config::Store] configuration persistence
    # @param detector [Detection::Runtime] runtime version detector
    # @param rails_detector [Detection::RailsVersions] Rails version detector
    # @param runner [Runner, nil] command runner (built from +out+ if nil)
    # @param prompter [UI::Prompter, nil] user interaction handler
    # @param palette [UI::Palette, nil] color palette for terminal output
    # @return [Integer] exit code (0 on success, non-zero on failure)
    def self.start(
      argv = ARGV,
      out: $stdout,
      err: $stderr,
      store: Config::Store.new,
      detector: Detection::Runtime.new,
      rails_detector: Detection::RailsVersions.new,
      runner: nil,
      prompter: nil,
      palette: nil
    )
      instance = new(
        argv: argv,
        out: out,
        err: err,
        store: store,
        detector: detector,
        rails_detector: rails_detector,
        runner: runner || Runner.new(out: out),
        prompter: prompter,
        palette: palette
      )
      instance.run
    end

    # @param argv [Array<String>] command-line arguments
    # @param out [IO] standard output stream
    # @param err [IO] standard error stream
    # @param store [Config::Store] configuration persistence
    # @param detector [Detection::Runtime] runtime version detector
    # @param rails_detector [Detection::RailsVersions] Rails version detector
    # @param runner [Runner] command runner
    # @param prompter [UI::Prompter, nil] user interaction handler
    # @param palette [UI::Palette, nil] color palette for terminal output
    def initialize(argv:, out:, err:, store:, detector:, rails_detector:, runner:, prompter:, palette:)
      @argv = argv.dup
      @out = out
      @err = err
      @store = store
      @detector = detector
      @rails_detector = rails_detector
      @runner = runner
      @prompter = prompter
      @palette = palette || UI::Palette.new
      @options = {}
    end

    # Runs the CLI: parses flags, dispatches to the appropriate action,
    # and returns an exit code.
    #
    # @return [Integer] exit code (0 success, 1 error, 130 interrupt)
    def run
      parse_options!

      validate_top_level_flags!

      return print_version if @options[:version]
      return doctor if @options[:doctor]
      return list_presets if @options[:list_presets]
      return show_preset if @options[:show_preset]
      return delete_preset if @options[:delete_preset]

      runtime_versions = @detector.detect!
      installed_rails = @rails_detector.detect
      version_choice = resolve_rails_version!(installed_rails)
      compatibility_entry = Compatibility::Matrix.for(version_choice.version || "#{version_choice.series}.0")
      builder = CommandBuilder.new(compatibility_entry: compatibility_entry)
      last_used = symbolize_keys(@store.last_used)

      app_name = resolve_app_name!
      selected_options =
        if @options[:preset]
          load_preset_options!
        else
          run_interactive_wizard!(
            app_name: app_name,
            builder: builder,
            compatibility_entry: compatibility_entry,
            last_used: last_used,
            runtime_versions: runtime_versions,
            version_choice: version_choice
          )
        end

      Options::Validator.new(compatibility_entry).validate!(app_name: app_name, options: selected_options)

      if version_choice.needs_install
        installed_version = install_rails!(version_choice)
        version_choice = VersionChoice.new(
          version: installed_version || version_choice.version,
          series: version_choice.series,
          needs_install: false
        )
      end

      command = builder.build(
        app_name: app_name,
        rails_version: version_choice.version,
        options: selected_options,
        minimal: @options[:minimal]
      )

      @runner.run!(command, dry_run: @options[:dry_run])
      @store.save_last_used(selected_options)
      save_preset_if_requested(selected_options)
      0
    rescue OptionParser::ParseError, Error => e
      @err.puts(e.message)
      1
    rescue Interrupt
      @err.puts(::CLI::UI.fmt('{{green:See ya!}}'))
      130
    end

    private

    attr_reader :palette

    # @return [void]
    def parse_options!
      OptionParser.new do |parser|
        parser.on('--preset NAME') { |value| @options[:preset] = value }
        parser.on('--save-preset NAME') { |value| @options[:save_preset] = value }
        parser.on('--list-presets') { @options[:list_presets] = true }
        parser.on('--show-preset NAME') { |value| @options[:show_preset] = value }
        parser.on('--delete-preset NAME') { |value| @options[:delete_preset] = value }
        parser.on('--doctor') { @options[:doctor] = true }
        parser.on('--version') { @options[:version] = true }
        parser.on('--dry-run') { @options[:dry_run] = true }
        parser.on('--rails-version VERSION') { |value| @options[:rails_version] = value }
        parser.on('--minimal') { @options[:minimal] = true }
      end.parse!(@argv)
    end

    # @raise [ValidationError] if conflicting flags are combined
    # @return [void]
    def validate_top_level_flags!
      conflicting_create_action = @options[:preset] || @options[:save_preset] || !@argv.empty?
      query_action = @options[:list_presets] || @options[:show_preset]
      if query_action && (@options[:delete_preset] || conflicting_create_action)
        raise ValidationError, 'Preset query options cannot be combined with other actions'
      end

      if @options[:delete_preset] && conflicting_create_action
        raise ValidationError, '--delete-preset cannot be combined with create actions'
      end

      if @options[:doctor] && (query_action || @options[:delete_preset] || conflicting_create_action)
        raise ValidationError, '--doctor cannot be combined with other actions'
      end

      conflicting_action = @options[:doctor] || query_action
      conflicting_action ||= @options[:delete_preset]
      conflicting_action ||= conflicting_create_action
      return unless @options[:version] && conflicting_action

      raise ValidationError, '--version cannot be combined with other actions'
    end

    # @return [Integer] exit code
    def print_version
      @out.puts(VERSION)
      0
    end

    # Prints runtime version info and supported options.
    #
    # @return [Integer] exit code
    def doctor
      runtime_versions = @detector.detect!
      @out.puts("ruby: #{runtime_versions.ruby}")
      @out.puts("rubygems: #{runtime_versions.rubygems}")
      installed_rails = @rails_detector.detect
      if installed_rails.empty?
        @out.puts('rails: not installed')
      else
        installed_rails.each { |series, version| @out.puts("rails #{series}: #{version}") }
      end
      Compatibility::Matrix::TABLE.each do |entry|
        range = entry.requirement.requirements.map(&:join).join(', ')
        options = Options::Catalog::ORDER.select { |key| entry.supports_option?(key) }
        @out.puts("options (#{range}): #{options.join(', ')}")
      end
      0
    end

    # @return [Integer] exit code
    def list_presets
      @store.preset_names.each { |name| @out.puts(name) }
      0
    end

    # @return [Integer] exit code
    # @raise [ValidationError] if the preset does not exist
    def show_preset
      preset = @store.preset(@options[:show_preset])
      raise ValidationError, "Preset not found: #{@options[:show_preset]}" unless preset

      @out.puts(@options[:show_preset])
      preset.sort.each { |key, value| @out.puts("  #{key}: #{value.inspect}") }
      0
    end

    # @return [Integer] exit code
    def delete_preset
      @store.delete_preset(@options[:delete_preset])
      0
    end

    # Resolves which Rails version to use without installing.
    #
    # Returns a {VersionChoice} indicating the selected version/series
    # and whether installation is needed (deferred until after the wizard).
    #
    # @param installed_rails [Hash{String => String}]
    # @return [VersionChoice]
    def resolve_rails_version!(installed_rails)
      if @options[:rails_version]
        version = @options[:rails_version]
        v = Gem::Version.new(version)
        if v.segments.length < 2
          raise ValidationError, "Rails version must have at least major.minor (e.g. 8.1), got: #{version}"
        end

        series = "#{v.segments[0]}.#{v.segments[1]}"
        Compatibility::Matrix.for(version)
        return VersionChoice.new(version: version, series: series, needs_install: !installed_rails.key?(series))
      end

      choices = build_version_choices(installed_rails)
      raise UnsupportedRailsVersionError, 'No supported Rails series available' if choices.empty?

      answer = prompter.choose(
        '{{bold:Select Rails version}}',
        options: choices.map { |c| c[:label] },
        default: choices.first[:label]
      )
      selected = choices.find { |c| c[:label] == answer }

      VersionChoice.new(
        version: selected[:version],
        series: selected[:series],
        needs_install: !selected[:installed]
      )
    end

    # Builds choice labels for version selection prompt.
    #
    # @param installed_rails [Hash{String => String}]
    # @return [Array<Hash>]
    def build_version_choices(installed_rails)
      Compatibility::Matrix::SUPPORTED_SERIES.reverse_each.map do |series|
        version = installed_rails[series]
        { label: "Rails #{series}", version: version, series: series, installed: !version.nil? }
      end
    end

    # Installs Rails if needed, with a spinner in normal mode or print in dry-run.
    #
    # @param version_choice [VersionChoice]
    # @return [String, nil] exact installed version, or nil in dry-run without exact version
    def install_rails!(version_choice)
      version_constraint = version_choice.version || "~> #{version_choice.series}.0"
      install_command = ['gem', 'install', 'rails', '-v', version_constraint]

      if @options[:dry_run]
        @runner.run!(install_command, dry_run: true)
        return version_choice.version
      end

      spin("Installing Rails #{version_choice.version || version_choice.series}") do
        @runner.run!(install_command)
      end

      return version_choice.version if version_choice.version

      refreshed = @rails_detector.detect
      version = refreshed[version_choice.series]
      unless version
        raise UnsupportedRailsVersionError,
              "Failed to detect Rails #{version_choice.series} after installation"
      end

      version
    end

    # @return [String] app name from argv or interactive prompt
    # @raise [ValidationError] if app name is required but missing
    def resolve_app_name!
      app_name = @argv.shift
      return app_name if app_name && !app_name.empty?

      raise ValidationError, 'App name is required when --preset is provided' if @options[:preset]

      prompter.text('App name:', allow_empty: false)
    end

    # @return [Hash{Symbol => Object}] preset options
    # @raise [ValidationError] if the preset does not exist
    def load_preset_options!
      preset = @store.preset(@options[:preset])
      raise ValidationError, "Preset not found: #{@options[:preset]}" unless preset

      symbolize_keys(preset)
    end

    # Runs the interactive wizard loop with summary + edit-again flow.
    #
    # @param app_name [String]
    # @param builder [CommandBuilder]
    # @param compatibility_entry [Compatibility::Matrix::Entry]
    # @param last_used [Hash{Symbol => Object}]
    # @param runtime_versions [Detection::RuntimeInfo]
    # @param version_choice [VersionChoice]
    # @return [Hash{Symbol => Object}] selected options
    def run_interactive_wizard!(
      app_name:,
      builder:,
      compatibility_entry:,
      last_used:,
      runtime_versions:,
      version_choice:
    )
      defaults = last_used
      prompter.frame('Controls') do
        prompter.say("Press #{palette.color(:control_back, 'Ctrl+B')} to go back one step.")
        prompter.say("Press #{palette.color(:control_exit, 'Ctrl+C')} to exit.")
      end
      loop do
        selected_options = Wizard.new(
          compatibility_entry: compatibility_entry,
          defaults: defaults,
          prompter: prompter
        ).run

        command = builder.build(
          app_name: app_name,
          rails_version: version_choice.version,
          options: selected_options,
          minimal: @options[:minimal]
        )
        show_summary(
          app_name: app_name,
          command: command,
          runtime_versions: runtime_versions,
          version_choice: version_choice
        )
        action = prompter.choose('Next step', options: ['create', 'edit again'], default: 'create')
        return selected_options if action == 'create'

        defaults = selected_options
      end
    end

    # @param app_name [String]
    # @param command [Array<String>]
    # @param runtime_versions [Detection::RuntimeInfo]
    # @param version_choice [VersionChoice]
    # @return [void]
    def show_summary(app_name:, command:, runtime_versions:, version_choice:)
      new_idx = command.index('new')
      return unless new_idx

      args = command[(new_idx + 2)..] || []

      prompter.frame('create-rails-app summary') do
        runtime_line = "#{palette.color(:summary_label, 'Runtime:')} "
        runtime_line += format_runtime_versions(runtime_versions, version_choice)
        prompter.say(runtime_line)

        if version_choice.needs_install
          constraint = version_choice.version || "~> #{version_choice.series}.0"
          install_line = "gem install rails -v '#{constraint}'"
          prompter.say("#{palette.color(:summary_label, 'Install:')} #{palette.color(:install_cmd, install_line)}")
        end

        command_line = "#{palette.color(:command_base, 'rails new')} "
        command_line += palette.color(:command_app, app_name)
        command_line += " #{format_args(args)}" unless args.empty?
        prompter.say("#{palette.color(:summary_label, 'Command:')} #{command_line}")
      end
    end

    # @param runtime_versions [Detection::RuntimeInfo]
    # @param version_choice [VersionChoice]
    # @return [String]
    def format_runtime_versions(runtime_versions, version_choice)
      rails_display = version_choice.version || "~> #{version_choice.series}"
      [
        ['ruby', runtime_versions.ruby],
        ['rubygems', runtime_versions.rubygems],
        ['rails', rails_display]
      ].map do |name, version|
        "#{palette.color(:runtime_name, name)} #{palette.color(:runtime_value, version.to_s)}"
      end.join(', ')
    end

    # @param args [Array<String>]
    # @return [String]
    def format_args(args)
      args.map { |argument| format_argument(argument) }.join(' ')
    end

    # @param argument [String]
    # @return [String]
    def format_argument(argument)
      return palette.color(:arg_value, argument) unless argument.start_with?('--')
      return palette.color(:arg_name, argument) unless argument.include?('=')

      name, value = argument.split('=', 2)
      "#{palette.color(:arg_name, name)}#{palette.color(:arg_eq, '=')}#{palette.color(:arg_value, value)}"
    end

    # @param selected_options [Hash{Symbol => Object}]
    # @return [void]
    def save_preset_if_requested(selected_options)
      if @options[:save_preset]
        save_preset_with_overwrite_check(@options[:save_preset], selected_options)
        return
      end

      return if @options[:preset]
      return unless prompter.confirm('Save these options as a preset?', default: false)

      preset_name = prompter.text('Preset name:', allow_empty: false)
      save_preset_with_overwrite_check(preset_name, selected_options)
    end

    # @param name [String]
    # @param options [Hash{Symbol => Object}]
    # @return [void]
    def save_preset_with_overwrite_check(name, options)
      validate_preset_name!(name)
      if @store.preset(name)
        return unless prompter.confirm("Preset '#{name}' already exists. Overwrite?", default: false)
      end
      @store.save_preset(name, options)
    end

    # @return [Regexp] pattern for valid preset names
    PRESET_NAME_PATTERN = /\A[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}\z/
    private_constant :PRESET_NAME_PATTERN

    # @param name [String]
    # @raise [ValidationError] if the name is invalid
    # @return [void]
    def validate_preset_name!(name)
      return if name.is_a?(String) && name.match?(PRESET_NAME_PATTERN)

      raise ValidationError,
            "Invalid preset name: #{name.inspect}. Use alphanumeric characters, dashes, or underscores (max 64 chars)."
    end

    # @param hash [Hash{String => Object}]
    # @return [Hash{Symbol => Object}]
    def symbolize_keys(hash)
      hash.transform_keys(&:to_sym)
    end

    # @return [UI::Prompter]
    def prompter
      @prompter ||= begin
        UI::Prompter.setup!
        UI::Prompter.new(out: @out)
      end
    end

    # Wrapper for CLI::UI::Spinner — easy to stub in tests.
    #
    # @param title [String]
    # @yield block to run with spinner
    # @return [void]
    def spin(title, &)
      ::CLI::UI::Spinner.spin(title, &)
    end
  end
end
