#
# Cookbook:: chef_auto_accumulator
# Library:: accumulator_config
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
  module Config
    # Auto accumulation configuration helper methods
    module Accumulator
      private

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

        unless path_tuple.any? { |v| v.is_a?(Array) }
          log_chef(:debug) { 'accumulator_config_path_contained_nested?: Config not nested' }
          return false
        end

        # Verify all options are type Array
        %w(option_config_path_match_key option_config_path_match_value option_config_path_contained_key).each do |opt|
          opt_val = send(opt.to_sym)
          next if opt_val.is_a?(Array)

          raise ChefAutoAccumulator::Resource::Options::ResourceOptionMalformedError.new(resource_type_name, opt, opt_val, 'Array')
        end

        log_chef(:debug) { 'accumulator_config_path_contained_nested?: Config nested' }
        true
      rescue ChefAutoAccumulator::Resource::Options::ResourceOptionNotDefinedError
        false
      end

      # Return the correct contaning key regardless of whether the configuration is nested or not
      #
      # @return [String, Symbol] The resources config containing Hash key
      #
      def accumulator_config_path_containing_key
        accumulator_config_path_contained_nested? ? option_config_path_contained_key.last : option_config_path_contained_key
      end
    end
  end
end
