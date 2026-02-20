# frozen_string_literal: true

module CreateRailsApp
  module Detection
    # Holds detected Ruby and RubyGems versions.
    #
    # @!attribute [r] ruby
    #   @return [Gem::Version]
    # @!attribute [r] rubygems
    #   @return [Gem::Version]
    RuntimeInfo = Struct.new(:ruby, :rubygems, keyword_init: true)

    # Detects the current Ruby and RubyGems versions.
    class Runtime
      # @return [RuntimeInfo]
      def detect!
        RuntimeInfo.new(
          ruby: Gem::Version.new(RUBY_VERSION),
          rubygems: Gem::Version.new(Gem::VERSION)
        )
      end
    end
  end
end
