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

require 'mixlib/log'

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

    # Return the resource declared name
    #
    # @return [String]
    #
    def resource_declared_name
      instance_variable_defined?(:@new_resource) ? new_resource.name : name
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
    def debug_var_output(var, inspect = true)
      output = "[#{var.class}] "
      output << case var
                when Array, Hash
                  "\n---\n#{var.pretty_inspect}---\n"
                when Symbol
                  var.to_s.prepend(':')
                else
                  var.to_s
                end if var && inspect

      output.strip
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
      return false unless object.respond_to?(:fetch)

      log_chef(:trace) { "Testing key #{debug_var_output(key)} and value #{debug_var_output(value)} against object #{debug_var_output(object)}" }
      result = object.fetch(key, nil).eql?(value)
      log_chef(:debug) { "Matched key #{debug_var_output(key)} and value #{debug_var_output(value)} against object #{debug_var_output(object)}" } if result

      result
    end

    # Call Chef::Log to log a message with the calling method appended
    #
    # @param severity [Symbol] Log severity
    # @param message [String] Log message
    # @yield Lazy loaded log message
    # @yieldreturn [String] Log message
    # @return [nil]
    #
    def log_chef(severity, message = nil)
      severity_int = Mixlib::Log::Logging::LEVELS[severity]
      level = Mixlib::Log::Logging::LEVELS[Chef::Log.level]

      return if severity.nil? || (severity_int < level)

      message = yield if block_given?
      calling_method = caller.find { |v| v.match?(/\.rb:\d+/) }[/`.*'/][1..-2]

      Chef::Log.send(severity, "#{calling_method}: #{message}")
    end
  end
end
