# frozen_string_literal: true

module CreateRailsApp
  module Options
    # Validates user-selected options against the compatibility entry
    # for the detected Rails version.
    #
    # Checks that: the app name is valid, every option key is known,
    # every option is supported by this Rails version, and every
    # value is valid for the option's type and allowed values.
    class Validator
      # @return [Regexp] pattern for valid Rails app names
      APP_NAME_PATTERN = /\A[a-zA-Z][a-zA-Z0-9_-]*\z/

      # @param compatibility_entry [Compatibility::Matrix::Entry]
      def initialize(compatibility_entry)
        @compatibility_entry = compatibility_entry
      end

      # Validates the app name and all options.
      #
      # @param app_name [String]
      # @param options [Hash{Symbol => Object}]
      # @return [true]
      # @raise [ValidationError] if any validation fails
      def validate!(app_name:, options:) # rubocop:disable Naming/PredicateMethod
        validate_app_name!(app_name)

        options.each do |key, value|
          validate_option_key!(key)
          validate_supported_option!(key)
          validate_value!(key, value)
          validate_supported_value!(key, value)
        end

        true
      end

      private

      # @param app_name [String]
      # @raise [ValidationError]
      # @return [void]
      def validate_app_name!(app_name)
        return if app_name.is_a?(String) && app_name.match?(APP_NAME_PATTERN)

        raise ValidationError, "Invalid app name: #{app_name.inspect}"
      end

      # @param key [Symbol]
      # @raise [ValidationError]
      # @return [void]
      def validate_option_key!(key)
        return if Catalog::DEFINITIONS.key?(key.to_sym)

        raise ValidationError, "Unknown option: #{key}"
      end

      # @param key [Symbol]
      # @raise [ValidationError]
      # @return [void]
      def validate_supported_option!(key)
        return if @compatibility_entry.supports_option?(key)

        raise ValidationError, "Option #{key} is not supported by this Rails version"
      end

      # @param key [Symbol]
      # @param value [Object]
      # @raise [ValidationError]
      # @return [void]
      def validate_value!(key, value)
        definition = Catalog.fetch(key)
        case definition[:type]
        when :skip, :flag
          return if value.nil? || value == true || value == false
        when :enum
          return if value.nil? || (value == false && definition.key?(:none)) || definition[:values].include?(value)
        end

        raise ValidationError, "Invalid value for #{key}: #{value.inspect}"
      end

      # @param key [Symbol]
      # @param value [Object]
      # @raise [ValidationError]
      # @return [void]
      def validate_supported_value!(key, value)
        return if value.nil? || value == true || value == false

        supported_values = @compatibility_entry.allowed_values(key)
        return if supported_values.nil? || supported_values.include?(value)

        raise ValidationError, "Value #{value.inspect} for #{key} is not supported by this Rails version"
      end
    end
  end
end
