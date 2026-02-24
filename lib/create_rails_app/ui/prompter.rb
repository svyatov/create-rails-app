# frozen_string_literal: true

require 'cli/ui'
require_relative 'back_navigation_patch'

module CreateRailsApp
  module UI
    # Thin wrapper around +cli-ui+ for all user interaction.
    #
    # Every prompt the wizard issues goes through this class, making it
    # easy to inject a test double.
    class Prompter
      # Enables the +cli-ui+ stdout router and applies the Ctrl+B patch.
      #
      # Call once before creating a Prompter instance. Idempotent.
      #
      # @return [void]
      def self.setup!
        ::CLI::UI::StdoutRouter.enable
        BackNavigationPatch.apply!
      end

      # @param out [IO] output stream
      def initialize(out: $stdout)
        @out = out
      end

      # Opens a visual frame with a title.
      #
      # @param title [String]
      # @yield block executed inside the frame
      # @return [void]
      def frame(title, &)
        ::CLI::UI::Frame.open(title, &)
      end

      # Presents a single-choice list.
      #
      # @param question [String]
      # @param options [Array<String>]
      # @param default [String, nil]
      # @return [String] selected option, or {Wizard::BACK} on Ctrl+B
      def choose(question, options:, default: nil)
        ::CLI::UI.ask(question, options: options, default: default, filter_ui: false)
      rescue BackKeyPressed
        Wizard::BACK
      end

      # Prompts for free-text input.
      #
      # @param question [String]
      # @param default [String, nil]
      # @param allow_empty [Boolean]
      # @return [String]
      def text(question, default: nil, allow_empty: true)
        ::CLI::UI.ask(question, default: default, allow_empty: allow_empty)
      rescue BackKeyPressed
        Wizard::BACK
      end

      # Prompts for yes/no confirmation.
      #
      # @param question [String]
      # @param default [Boolean]
      # @return [Boolean]
      def confirm(question, default: true)
        ::CLI::UI.confirm(question, default: default)
      rescue BackKeyPressed
        default
      end

      # Prints a formatted message to the output stream.
      #
      # @param message [String] message with optional +cli-ui+ formatting tags
      # @return [void]
      def say(message)
        @out.puts(::CLI::UI.fmt(message))
      end
    end
  end
end
