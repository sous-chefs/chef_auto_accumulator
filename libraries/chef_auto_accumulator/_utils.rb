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
    # @param gem_name [String] Gem name to check
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

    # Return the resource declared type name
    #
    # @return [String]
    #
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

    # Test a key value pair for an object with logging output on match
    #
    # @param object [Hash] Object to check
    # @param key [String, Symbol] Key to fetch and test
    # @param value [Any] Value to test against
    # @return [true, false]
    #
    def kv_test_log(object, key, value)
      raise ArgumentError, "Object #{debug_var_output(object)} does not respond to :fetch" unless object.respond_to?(:fetch)

      Chef::Log.trace("kv_test_log: Testing key #{debug_var_output(key)} and value #{debug_var_output(value)} against object #{debug_var_output(object)}")
      result = object.fetch(key, nil).eql?(value)
      Chef::Log.warn("kv_test_log: Matched key #{debug_var_output(key)} and value #{debug_var_output(value)} against object #{debug_var_output(object)}") if result

      result
    end
  end
end
