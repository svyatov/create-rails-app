# frozen_string_literal: true

module CreateRailsApp
  module UI
    # Raised when the user presses Ctrl+B during a prompt.
    #
    # @api private
    class BackKeyPressed < StandardError; end

    # Monkey-patches +CLI::UI::Prompt+ to intercept Ctrl+B for back-navigation.
    #
    # @api private
    module BackNavigationPatch
      # ASCII code for Ctrl+B.
      CTRL_B = "\u0002"

      # Patch module prepended onto +CLI::UI::Prompt.singleton_class+.
      module PromptReadCharPatch
        # @raise [BackKeyPressed] when the user presses Ctrl+B
        # @return [String] the character read
        def read_char
          char = super

          raise BackKeyPressed if char == BackNavigationPatch::CTRL_B

          char
        end
      end

      # Prepends the Ctrl+B patch onto +CLI::UI::Prompt+ (idempotent).
      #
      # @return [void]
      def self.apply!
        unless ::CLI::UI::Prompt.respond_to?(:read_char)
          raise Error, 'CLI::UI::Prompt does not respond to read_char; back-navigation patch cannot be applied'
        end

        singleton = ::CLI::UI::Prompt.singleton_class
        return if singleton.ancestors.include?(PromptReadCharPatch)

        singleton.prepend(PromptReadCharPatch)
      end
    end
  end
end
