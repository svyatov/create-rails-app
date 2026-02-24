# frozen_string_literal: true

require 'fileutils'
require 'tempfile'
require 'yaml'

module CreateRailsApp
  module Config
    # YAML persistence for presets and last-used options.
    #
    # Stores configuration at +~/.config/create-rails-app/config.yml+ (or
    # +$XDG_CONFIG_HOME/create-rails-app/config.yml+). Writes are atomic
    # via +Tempfile+ + rename.
    class Store
      # @return [Integer] current config file schema version
      SCHEMA_VERSION = 1

      # @param path [String, nil] override the default config file path
      def initialize(path: nil)
        @path = path || default_path
      end

      # @return [String] absolute path to the config file
      attr_reader :path

      # Returns the last-used option hash (empty hash if none saved).
      #
      # @return [Hash{String => Object}]
      def last_used
        data.fetch('last_used')
      end

      # Persists the given options as last-used.
      #
      # @param options [Hash{Symbol => Object}]
      # @return [void]
      def save_last_used(options)
        payload = data
        payload['last_used'] = stringify_keys(options)
        write(payload)
      end

      # Returns a preset by name, or +nil+ if it does not exist.
      #
      # @param name [String]
      # @return [Hash{String => Object}, nil]
      def preset(name)
        data.fetch('presets').fetch(name.to_s, nil)
      end

      # Returns all preset names sorted alphabetically.
      #
      # @return [Array<String>]
      def preset_names
        data.fetch('presets').keys.sort
      end

      # Saves a named preset.
      #
      # @param name [String]
      # @param options [Hash{Symbol => Object}]
      # @return [void]
      def save_preset(name, options)
        payload = data
        payload.fetch('presets')[name.to_s] = stringify_keys(options)
        write(payload)
      end

      # Deletes a named preset (no-op if it does not exist).
      #
      # @param name [String]
      # @return [void]
      def delete_preset(name)
        payload = data
        payload.fetch('presets').delete(name.to_s)
        write(payload)
      end

      private

      # @return [Hash{String => Object}]
      def data
        raw = load
        {
          'version' => raw.fetch('version', SCHEMA_VERSION),
          'last_used' => (raw['last_used'].is_a?(Hash) ? raw['last_used'] : {}),
          'presets' => (raw['presets'].is_a?(Hash) ? raw['presets'] : {})
        }
      end

      # @return [Hash]
      # @raise [ConfigError] if YAML is malformed
      def load
        return {} unless File.file?(path)

        result = YAML.safe_load_file(path, aliases: false)
        unless result.nil? || result.is_a?(Hash)
          raise ConfigError, "Invalid config file at #{path}: expected a YAML mapping"
        end

        version = result&.fetch('version', SCHEMA_VERSION) || SCHEMA_VERSION
        unless version.is_a?(Integer)
          raise ConfigError, "Invalid config version at #{path}: expected integer, got #{version.inspect}"
        end

        if version > SCHEMA_VERSION
          raise ConfigError,
                "Config file at #{path} has unsupported version #{version} (expected #{SCHEMA_VERSION}). " \
                'Please upgrade create-rails-app or delete the config file.'
        end

        result || {}
      rescue Psych::SyntaxError, Psych::DisallowedClass => e
        raise ConfigError, "Invalid config file at #{path}: #{e.message}"
      end

      # @param payload [Hash]
      # @return [void]
      def write(payload)
        FileUtils.mkdir_p(File.dirname(path))
        tmp = Tempfile.create(['create-rails-app', '.yml'], File.dirname(path))
        tmp.write(YAML.dump(payload))
        tmp.close
        File.rename(tmp.path, path)
      rescue SystemCallError => e
        File.unlink(tmp.path) if tmp&.path && File.exist?(tmp.path)
        raise ConfigError, "Failed to write config to #{path}: #{e.message}"
      end

      # @return [String]
      def default_path
        config_home = ENV.fetch('XDG_CONFIG_HOME', File.join(Dir.home, '.config'))
        File.join(config_home, 'create-rails-app', 'config.yml')
      rescue ArgumentError
        raise ConfigError, 'Cannot determine home directory. Set HOME or XDG_CONFIG_HOME.'
      end

      # @param hash [Hash{Symbol => Object}]
      # @return [Hash{String => Object}]
      def stringify_keys(hash)
        hash.transform_keys(&:to_s)
      end
    end
  end
end
