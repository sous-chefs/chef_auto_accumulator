#
# Cookbook:: chef_auto_accumulator
# Library:: resource_options
#
# Copyright:: Ben Hughes <bmhughes@bmhughes.co.uk>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module ChefAutoAccumulator
  module Resource
    # Resource property Hash accessor method and option value retrieval convience methods
    module Options
      # List of allowed accumulated configuration path types
      ALLOWED_PATH_TYPES = %i(hash hash_contained array array_contained).freeze
      private_constant :ALLOWED_PATH_TYPES

      private

      # Return the configuration file type from resource options
      #
      # @return [Symbol] Configuration file type
      #
      def option_config_file_type
        type = resource_options.fetch(:config_file_type, nil)
        Chef::Log.debug("config_file_type: #{debug_var_output(type)}")

        raise ResourceOptionMalformedError.new(resource_type_name, 'config_file_type', type, 'String', 'Symbol') unless multi_is_a?(type, String, Symbol)

        type.upcase.to_sym
      end

      # Return the base configuration path to strip
      #
      # @return [Array, nil] Configured base path or nil if not defined
      #
      def option_config_base_path
        base = resource_options.fetch(:config_base_path, nil)
        Chef::Log.debug("option_config_base_path: #{debug_var_output(base)}")

        return unless base

        raise ResourceOptionMalformedError.new(resource_type_name, 'config_base_path', base, 'String') unless base.is_a?(String)

        base
      end

      # Return the resource configuration path override (if defined)
      #
      # @return [Array, nil] Configured path override or nil if not defined
      #
      def option_config_path_override
        path = resource_options.fetch(:config_path_override, nil)
        Chef::Log.debug("option_config_path_override: #{debug_var_output(path)}")

        return unless path

        raise ResourceOptionMalformedError.new(resource_type_name, 'config_path_override', path, 'Array') unless path.is_a?(Array)

        path
      end

      # Return the resource configuration path type
      #
      # @return [Symbol, nil] Path type
      #
      def option_config_path_type
        type = resource_options.fetch(:config_path_type, :hash)

        Chef::Log.debug("option_config_path_type: #{debug_var_output(type)}")
        raise ResourceOptionMalformedError.new(resource_type_name, 'config_path_type', type, *ALLOWED_PATH_TYPES) unless ALLOWED_PATH_TYPES.include?(type)

        type
      end

      # Return the key to match the resource configuration path against
      #
      # @return [Symbol, String, Array] Path type
      #
      def option_config_path_match_key
        match_key = resource_options.fetch(:config_path_match_key, nil)
        Chef::Log.debug("option_config_path_match_key: #{debug_var_output(match_key)}")

        raise ResourceOptionMalformedError.new(resource_type_name, 'config_path_match_key', match_key, 'String', 'Symbol') unless multi_is_a?(match_key, String, Symbol, Array)

        match_key
      end

      # Return the value to match the resource configuration path against
      #
      # @return [Any] Path type
      #
      def option_config_path_match_value
        match_value = resource_options.fetch(:config_path_match_value, nil)
        Chef::Log.debug("option_config_path_match_value: #{debug_var_output(match_value)}")

        raise ResourceOptionNotDefinedError.new(resource_type_name, 'config_path_match_value', match_value) unless match_value

        match_value
      end

      # Return the key to store the contained configuration in on the filtered configuration path object
      #
      # @return [Symbol, String, Array] Path type
      #
      def option_config_path_contained_key
        contained_key = resource_options.fetch(:config_path_contained_key, nil)
        Chef::Log.debug("option_config_path_contained_key: #{debug_var_output(contained_key)}")

        raise ResourceOptionNotDefinedError.new(resource_type_name, 'config_path_contained_key', contained_key) unless contained_key

        contained_key
      end

      # Return the key to match the resource configuration against for load_current_value
      #
      # @return [Symbol] Path type
      #
      def option_config_match_key
        match_key = resource_options.fetch(:config_match_key, nil)
        Chef::Log.debug("option_config_match_key: #{debug_var_output(match_key)}")

        raise ResourceOptionNotDefinedError.new(resource_type_name, 'config_match_key', match_key) unless match_key

        match_key
      end

      # Return the value to match the resource configuration against for load_current_value
      #
      # @return [Symbol] Path type
      #
      def option_config_match_value
        match_value = resource_options.fetch(:config_match_value, nil)
        Chef::Log.debug("option_config_match_value: #{debug_var_output(match_value)}")

        raise ResourceOptionNotDefinedError.new(resource_type_name, 'config_match_value', match_value) unless match_value

        match_value
      end

      # Return the resource configuration path override (if defined)
      #
      # @return [Array, nil] Configured path override or nil if not defined
      #
      def option_config_properties_skip
        skip = resource_options.fetch(:config_properties_skip, nil)
        Chef::Log.debug("option_config_properties_skip: #{debug_var_output(skip)}")

        return unless skip

        raise ResourceOptionMalformedError.new(resource_type_name, 'config_properties_skip', skip, 'Array') unless skip.is_a?(Array)

        skip
      end

      # Return the property name gsub defined in the resource options
      #
      # @return [String, nil] Resource options or nil if not defined
      #
      def option_property_name_gsub
        gsub = resource_options.fetch(:property_name_gsub, nil)
        Chef::Log.debug("option_property_name_gsub: #{debug_var_output(gsub)}")

        return unless gsub
        raise ResourceOptionMalformedError.new(resource_type_name, 'property_name_gsub', property_name_gsub, 'Array of 2 String') unless gsub.is_a?(Array) &&
                                                                                                                     gsub.count.eql?(2) &&
                                                                                                                     gsub.all? { |v| v.is_a?(String) }

        gsub
      end

      # Return the resource property translation matrix (if defined)
      #
      # @return [Hash, nil] Translation matrix or nil if not defined
      #
      def option_property_translation_matrix
        matrix = resource_options.fetch(:property_translation_matrix, nil)
        Chef::Log.debug("option_property_translation_matrix: #{debug_var_output(matrix)}")

        return unless matrix
        raise ResourceOptionMalformedError.new(resource_type_name, 'property_translation_matrix', matrix, 'Hash') unless matrix.is_a?(Hash)

        matrix
      end

      # Get the actual resource options for the resource (if defined)
      #
      # @return [Hash] Resource options
      #
      def resource_options
        options = if !action_class? && respond_to?(:auto_accumulator_options)
                    auto_accumulator_options
                  elsif action_class? && new_resource.respond_to?(:auto_accumulator_options)
                    new_resource.auto_accumulator_options
                  end

        # Per-resource overrides
        overrides = if !action_class? && respond_to?(:auto_accumulator_options_override)
                      auto_accumulator_options_override
                    elsif action_class? && new_resource.respond_to?(:auto_accumulator_options_override)
                      new_resource.auto_accumulator_options_override
                    end

        if overrides
          Chef::Log.trace("resource_options: Override options - #{debug_var_output(overrides)}")
          options = options.merge(overrides).freeze
        end

        Chef::Log.debug("resource_options: Merged options - #{debug_var_output(options)}")
        return {} unless options

        raise ResourceOptionMalformedError.new(resource_type_name, 'options', options, 'Hash') unless options.is_a?(Hash)

        options
      end

      # Error to raise when attemping to retrieve an option that is not defined on the resource
      class ResourceOptionNotDefinedError < BaseError
        include ChefAutoAccumulator::Utils

        def initialize(name, option, received_value)
          super("Unable to retrieve option #{option} for resource #{name}, received #{debug_var_output(received_value)}")
        end
      end

      # Error to raise when an incorrect type is returning when retrieving an option value
      class ResourceOptionMalformedError < BaseError
        include ChefAutoAccumulator::Utils

        def initialize(name, option, received_value, *expected_value)
          super("Type error occured retrieving option #{option} for resource #{name}. Expected #{expected_value.join(', ')}, received #{debug_var_output(received_value)}")
        end
      end
    end
  end
end