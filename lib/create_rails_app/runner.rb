# frozen_string_literal: true

require 'cli/kit'
require 'shellwords'

module CreateRailsApp
  # Executes commands via the shell.
  #
  # Supports +--dry-run+ mode, which prints commands instead of running them.
  # Can run multiple commands in sequence (e.g. gem install + rails new).
  #
  # @example
  #   Runner.new.run!(['rails', '_8.1.2_', 'new', 'myapp', '--api'])
  class Runner
    # @param out [IO] output stream for dry-run printing
    # @param system_runner [#call, nil] callable that executes a shell command
    def initialize(out: $stdout, system_runner: nil)
      @out = out
      @system_runner = system_runner || ->(*command) { ::CLI::Kit::System.system(*command) }
    end

    # Executes the command or prints it in dry-run mode.
    #
    # @param command [Array<String>] the command to execute
    # @param dry_run [Boolean] when true, prints instead of executing
    # @return [true] on success
    # @raise [Error] if the command exits with a non-zero status
    def run!(command, dry_run: false)
      if dry_run
        @out.puts(command.shelljoin)
        return true
      end

      status = @system_runner.call(*command)
      return true if status.respond_to?(:success?) && status.success?

      raise Error, "Command failed: #{command.shelljoin}"
    end
  end
end
