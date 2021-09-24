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

    # Return whether we are being called from the action_class or the outer resource class
    #
    # @return [true, false] True if we are being called from the action_class, otherwise false
    #
    def action_class?
      instance_variable_defined?(:@new_resource)
    end

    # Return the formatted Class and value of a variable for debug output
    #
    # @return [String] The formatted debug output
    #
    def debug_var_output(var)
      output = "[#{var.class}]"
      output.concat(" #{var}") if var

      output
    end
  end
end
