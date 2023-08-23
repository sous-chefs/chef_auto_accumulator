#
# Cookbook:: chef_auto_accumulator
# Library:: config_file
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

require_relative '../_utils'
require_relative '../file'

module ChefAutoAccumulator
  module Config
    # Provides load_current_value support
    module LoadCurrentValue
      private

      def config_file_current_data(filetype: config_file_type, config_file: option_config_file, cache: true)
        return unless ::File.exist?(config_file)

        if cache && (run_state_cache(:file).key?(config_file) && run_state_cache(:file)[config_file].is_a?(ChefAutoAccumulator::Config::File))
          log_chef(:debug) { "Returning file object from cache for: #{config_file}" }
          log_chef(:trace) { "File #{config_file} data\n#{debug_var_output(run_state_cache(:file).fetch(config_file).contents)}" }

          return run_state_cache(:file).fetch(config_file).contents
        end

        nil
      end

      # Return a resources property values from disk (if it exists)
      #
      # @param filetype [Symbol] The configuration file type
      # @param config_file [String] The configuration file to load
      # @param cache [TrueClass, FalseClass] Control data caching
      # @param new_resource [Chef::Resource] New resource data
      # @return [Hash] Resource property data
      #
      def config_file_current_resource_data(filetype: config_file_type, config_file: option_config_file, cache: true, new_resource:)
        return unless ::File.exist?(config_file)

        if cache && (run_state_cache(:file).key?(config_file) && run_state_cache(:file)[config_file].is_a?(ChefAutoAccumulator::Config::File))
          log_chef(:debug) { "Returning file object from cache for: #{config_file}" }
          log_chef(:trace) { "File #{config_file} data\n#{debug_var_output(run_state_cache(:file).fetch(config_file).contents)}" }
        else
          log_chef(:debug) { "Creating new file object for: #{config_file}" }
          run_state_cache(:file)[config_file] = ChefAutoAccumulator::Config::File.new(filetype: filetype, file: config_file, new_resource: new_resource)
          run_state_cache(:file)[config_file].load!
        end

        current_config = run_state_cache(:file).fetch(config_file)
        current_config.new_resource = new_resource

        log_chef(:debug) { "Resource path type: #{option_config_path_type}" }
        config = case option_config_path_type
                 when :array
                   current_config.file_section_item
                 when :array_contained
                   current_config.file_section_contained_item
                  when :array_contained_hash
                    section = current_config.file_section_item
                    section.fetch(option_config_path_contained_key, nil) if section.is_a?(Hash)
                 when :hash
                   current_config.file_section
                 when :hash_contained
                   section = current_config.file_section
                   section.fetch(option_config_path_contained_key, nil) if section.is_a?(Hash)
                 end.dup

        log_chef(:debug) { "Resource config: #{debug_var_output(config)}" }
        config
      end

      # Test if a resources configuration is present on disk
      #
      # @return [true, false] Test result
      #
      def config_file_current_resource_data?(filetype: config_file_type, config_file: option_config_file, cache: true, new_resource:)
        result = !config_file_current_resource_data(filetype: filetype, config_file: config_file, cache: cache, new_resource: new_resource).nil?
        log_chef(:info) { "Result: #{debug_var_output(result)}" }

        result
      end
    end
  end
end
