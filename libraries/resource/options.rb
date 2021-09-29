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

        raise ArgumentError, "Config file type must be specified as a Symbol or String, got #{debug_var_output(type)}" unless type.is_a?(Symbol) || type.is_a?(String)

        type.upcase.to_sym
      end

      # Return the base configuration path to strip
      #
      # @return [Array, nil] Configured base path
      #
      def option_config_base_path
        base = resource_options.fetch(:config_base_path, nil)
        Chef::Log.debug("option_config_base_path: #{debug_var_output(base)}")

        return unless base

        raise ArgumentError, "Resource base path should be specified as an String, got #{debug_var_output(base)}" unless base.is_a?(String)

        base
      end

      # Return the resource configuration path override (if defined)
      #
      # @return [Array, nil] Configured path override
      #
      def option_config_path_override
        path = resource_options.fetch(:config_path_override, nil)
        Chef::Log.debug("option_config_path_override: #{debug_var_output(path)}")

        return unless path

        raise ArgumentError, "Path override should be specified as an Array, got #{debug_var_output(path)}" unless path.is_a?(Array)

        path
      end

      # Return the resource configuration path type
      #
      # @return [Symbol, nil] Path type
      #
      def option_config_path_type
        type = resource_options.fetch(:config_path_type, :hash)

        raise ArgumentError, "Invalid path type #{type}" unless ALLOWED_PATH_TYPES.include?(type)
        Chef::Log.debug("option_config_path_type: #{debug_var_output(type)}")

        type
      end

      # Return the key to match the resource configuration path against
      #
      # @return [Symbol, nil] Path type
      #
      def option_config_path_match_key
        match_key = resource_options.fetch(:config_path_match_key, nil)
        Chef::Log.debug("option_config_path_match_key: #{debug_var_output(match_key)}")

        raise ArgumentError, "Match key must be String or Symbol, got #{debug_var_output(match_key)}" unless match_key.is_a?(String) ||
                                                                                                             match_key.is_a?(Symbol)

        match_key
      end

      # Return the value to match the resource configuration path against
      #
      # @return [Symbol, nil] Path type
      #
      def option_config_path_match_value
        match_value = resource_options.fetch(:config_path_match_value, nil)
        Chef::Log.debug("option_config_path_match_value: #{debug_var_output(match_value)}")

        raise ArgumentError, 'Match value must be set if config path type is :array' unless match_value

        match_value
      end

      # Return the key to store the contained configuration in on the filtered configuration path object
      #
      # @return [Symbol, nil] Path type
      #
      def option_config_path_contained_key
        contained_key = resource_options.fetch(:config_path_contained_key, nil)
        Chef::Log.debug("option_config_path_contained_key: #{debug_var_output(contained_key)}")

        raise ArgumentError, "Contained key not set, got #{debug_var_output(contained_key)}" unless contained_key

        contained_key
      end

      # Return the key to match the resource configuration against for load_current_value
      #
      # @return [Symbol, nil] Path type
      #
      def option_config_match_key
        match_key = resource_options.fetch(:config_match_key, nil)
        Chef::Log.debug("option_config_match_key: #{debug_var_output(match_key)}")

        raise ArgumentError, 'No LCV match key specified' unless match_key

        match_key
      end

      # Return the value to match the resource configuration against for load_current_value
      #
      # @return [Symbol, nil] Path type
      #
      def option_config_match_value
        match_value = resource_options.fetch(:config_match_value, nil)
        Chef::Log.debug("option_config_match_value: #{debug_var_output(match_value)}")

        raise ArgumentError, 'No LCV match value specified' unless match_value

        match_value
      end

      # Return the resource configuration path override (if defined)
      #
      # @return [Array, nil] Configured path override
      #
      def option_config_properties_skip
        skip = resource_options.fetch(:config_properties_skip, nil)
        Chef::Log.debug("option_config_properties_skip: #{debug_var_output(skip)}")

        return unless skip

        raise ArgumentError, "Resource properties to skip should be specified as an Array, got #{debug_var_output(skip)}" unless skip.is_a?(Array)

        skip
      end

      # Return the property name gsub defined in the resource options
      #
      # @return [String, nil] Resource options
      #
      def option_property_name_gsub
        gsub = resource_options.fetch(:property_name_gsub, nil)
        Chef::Log.debug("option_property_name_gsub: #{debug_var_output(gsub)}")

        return unless gsub
        raise ArgumentError,
              "Property gsub configuration must be specified as a Array of two Strings, got #{debug_var_output(gsub)}" unless gsub.is_a?(Array) &&
                                                                                                                              gsub.count.eql?(2) &&
                                                                                                                              gsub.all? { |v| v.is_a?(String) }

        gsub
      end

      # Return the resource property translation matrix (if defined)
      #
      # @return [Hash, nil] Translation matrix
      #
      def option_property_translation_matrix
        matrix = resource_options.fetch(:property_translation_matrix, nil)
        Chef::Log.debug("option_property_translation_matrix: #{debug_var_output(matrix)}")

        return unless matrix
        raise ArgumentError, "Property translation matrix configuration must be specified as a Hash, got #{debug_var_output(matrix)}" unless matrix.is_a?(Hash)

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
          Chef::Log.debug("resource_options: Override #{debug_var_output(overrides)}")
          options = options.merge(overrides).freeze
        end

        Chef::Log.debug("resource_options: #{debug_var_output(options)}")
        return {} unless options

        raise ArgumentError, "The resource options should be defined as a Hash, got #{options.class}" unless options.is_a?(Hash)

        options
      end
    end
  end
end
