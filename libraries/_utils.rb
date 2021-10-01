#
# Cookbook:: chef_auto_accumulator
# Library:: _utils
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
  # General utility methods
  module Utils
    private

    # Check if a given object(s) are either Nil or Empty
    #
    # @return [true, false] Nil or Empty check result
    #
    def nil_or_empty?(*values)
      values.any? { |v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }
    end

    # Check if a given gem is installed and available for require
    #
    # @return [true, false] Gem installed result
    #
    def gem_installed?(gem_name)
      !Gem::Specification.find_by_name(gem_name).nil?
    rescue Gem::LoadError
      false
    end

    # Return whether we are being called from the Chef resource action_class or the outer definition class
    #
    # @return [true, false] True if we are being called from the action_class, otherwise false
    #
    def action_class?
      instance_variable_defined?(:@new_resource)
    end

    def resource_type_name
      instance_variable_defined?(:@new_resource) ? new_resource.declared_type.to_s : resource_name.to_s
    end

    # Return the formatted class name and value (if not Nil) of a variable for debug output
    #
    # @return [String] The formatted debug output
    #
    def debug_var_output(var)
      output = "[#{var.class}]"
      if var
        var_output = var.to_s
        var_output.prepend(':') if var.is_a?(Symbol)
        output.concat(" #{var_output}")
      end

      output
    end

    # Test an object against multiple Classes to see if it is an instance of any of them
    #
    # @param object [Any] Object to test
    # @param classes [Class] Class(es) to test against
    # @return [true, false] Test result
    #
    def multi_is_a?(object, *classes)
      classes.any? { |c| object.is_a?(c) }
    end

    # Return whether a provided configuration path is contained and nested within multiple levels
    #
    # A contained nested item exists when multiple levels of configuration must be searched to find
    # the path of the item that are performing a CRUD operation upon.
    #
    # { top_level => { first_search_item => { second_search_item => { config_item => config_item_value } } } }
    #
    # @return [true, false]
    #
    def accumulator_config_path_contained_nested?
      path_tuple = [ option_config_path_match_key, option_config_path_match_value, option_config_path_contained_key ]

      return false unless path_tuple.any? { |v| v.is_a?(Array) }

      raise ResourceOptionMalformedError,
            'Contained nested configuration items require Search Item, Search and Contained Key to be specified as an Array' unless path_tuple.all? { |v| v.is_a?(Array) }

      true
    rescue ChefAutoAccumulator::Resource::Options::ResourceOptionNotDefinedError
      false
    end
  end
end
