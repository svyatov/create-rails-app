# frozen_string_literal: true

module CreateRailsApp
  # Converts an app name, Rails version, and option hash into a
  # +rails new+ command array.
  #
  # @example
  #   entry = Compatibility::Matrix.for('8.1.0')
  #   builder = CommandBuilder.new(compatibility_entry: entry)
  #   builder.build(app_name: 'myapp', rails_version: '8.1.2', options: { api: true, database: 'postgresql' })
  #   #=> ['rails', '_8.1.2_', 'new', 'myapp', '--api', '--database=postgresql']
  class CommandBuilder
    # Builds the +rails new+ command array.
    #
    # @param app_name [String]
    # @param rails_version [String, nil] exact version for version pinning (nil omits pin)
    # @param options [Hash{Symbol => Object}]
    # @param minimal [Boolean] pass +--minimal+ flag
    # @return [Array<String>]
    def build(app_name:, rails_version: nil, options: {}, minimal: false)
      command = ['rails']
      command << "_#{rails_version}_" if rails_version
      command.push('new', app_name)
      command << '--minimal' if minimal

      Options::Catalog::ORDER.each do |key|
        next unless options.key?(key)

        append_option!(command, key, options[key])
      end
      command
    end

    private

    # @param command [Array<String>]
    # @param key [Symbol]
    # @param value [Object]
    # @return [void]
    def append_option!(command, key, value)
      definition = Options::Catalog.fetch(key)
      case definition[:type]
      when :skip
        command << definition[:skip_flag] if value == false
      when :flag
        command << definition[:on] if value == true
      when :enum
        command << "#{definition[:flag]}=#{value}" if value.is_a?(String)
        command << definition[:none] if value == false
      end
    end
  end
end
