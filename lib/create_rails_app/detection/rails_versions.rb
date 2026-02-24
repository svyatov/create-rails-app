# frozen_string_literal: true

require 'open3'
require 'timeout'

module CreateRailsApp
  module Detection
    # Detects locally installed Rails versions using +gem list+.
    #
    # Groups installed versions by supported series (7.2, 8.0, 8.1)
    # and returns the latest patch version for each installed series.
    class RailsVersions
      # @return [Regexp] pattern to extract version strings from gem list output
      VERSION_PATTERN = /\d+\.\d+\.\d+(?:\.\w+)?/

      # @param gem_command [String] path or name of the gem executable
      def initialize(gem_command: 'gem')
        @gem_command = gem_command
      end

      # Detects installed Rails versions grouped by supported series.
      #
      # @return [Hash{String => String}] series => latest patch version
      #   e.g. { "8.0" => "8.0.7", "8.1" => "8.1.2" }
      def detect
        versions = installed_versions
        group_by_series(versions)
      end

      private

      # @return [Array<Gem::Version>] all installed Rails versions, sorted descending
      def installed_versions
        output, status = Timeout.timeout(10) do
          Open3.capture2e(@gem_command, 'list', 'rails', '--local', '--exact')
        end
        return [] unless status.success?

        rails_line = output.lines.find { |line| line.match?(/\Arails\s/) }
        return [] unless rails_line

        versions = rails_line.scan(VERSION_PATTERN).map { |v| Gem::Version.new(v) }
        versions.sort.reverse
      rescue SystemCallError, Timeout::Error
        []
      end

      # @param versions [Array<Gem::Version>]
      # @return [Hash{String => String}]
      def group_by_series(versions)
        result = {}
        Compatibility::Matrix::SUPPORTED_SERIES.each do |series|
          requirement = Gem::Requirement.new("~> #{series}.0")
          match = versions.find { |v| requirement.satisfied_by?(v) }
          result[series] = match.to_s if match
        end
        result
      end
    end
  end
end
