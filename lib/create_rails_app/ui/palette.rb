# frozen_string_literal: true

module CreateRailsApp
  module UI
    # Color constants for terminal output.
    #
    # Maps semantic roles (e.g. +:summary_label+, +:arg_name+) to ANSI 256-color
    # codes or +cli-ui+ basic color names, depending on terminal capabilities.
    class Palette
      # ANSI reset sequence.
      RESET = "\e[0m"

      # Role-to-color mappings for 256-color terminals.
      #
      # @return [Hash{Symbol => Integer}]
      ROLE_COLORS_256 = {
        control_back: 45,
        control_exit: 203,
        summary_label: 213,
        runtime_name: 111,
        runtime_value: 190,
        command_base: 39,
        command_app: 82,
        arg_name: 117,
        arg_eq: 250,
        arg_value: 214,
        install_cmd: 178
      }.freeze

      # Role-to-color mappings for basic (8/16-color) terminals.
      #
      # @return [Hash{Symbol => String}]
      ROLE_COLORS_BASIC = {
        control_back: 'cyan',
        control_exit: 'red',
        summary_label: 'magenta',
        runtime_name: 'blue',
        runtime_value: 'green',
        command_base: 'blue',
        command_app: 'green',
        arg_name: 'blue',
        arg_eq: 'white',
        arg_value: 'yellow',
        install_cmd: 'yellow'
      }.freeze

      # @param env [Hash] environment variables (defaults to +ENV+)
      def initialize(env: ENV)
        @env = env
      end

      # Wraps text in the appropriate ANSI color for the given role.
      #
      # @param role [Symbol] a key from {ROLE_COLORS_256}/{ROLE_COLORS_BASIC}
      # @param text [String] the text to colorize
      # @return [String]
      def color(role, text)
        if no_color?
          ROLE_COLORS_256.fetch(role) # validate role key exists
          text
        elsif supports_256_colors?
          "\e[38;5;#{ROLE_COLORS_256.fetch(role)}m#{text}#{RESET}"
        else
          "{{#{ROLE_COLORS_BASIC.fetch(role)}:#{text}}}"
        end
      end

      private

      # @return [Boolean]
      def no_color?
        @env.key?('NO_COLOR')
      end

      # @return [Boolean]
      def supports_256_colors?
        return false if no_color?

        term = @env.fetch('TERM', '')
        colorterm = @env.fetch('COLORTERM', '')
        term.include?('256color') || colorterm.match?(/truecolor|24bit/i)
      end
    end
  end
end
