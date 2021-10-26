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
    # On disk configuration state access, required for load_current_value support
    module File
      private

      # Load the on disk configuration file
      #
      # @param config_file [String] The configuration file to load
      # @return [Hash] Configuration file contents
      #
      def load_config_file(config_file)
        return unless ::File.exist?(config_file)

        config = load_file(config_file)
        Chef::Log.debug("load_config_file: #{config_file} Count - #{config.count}")
        Chef::Log.trace("load_config_file: #{config_file} - #{debug_var_output(config)}")

        config
      end

      # Load a section from the on disk configuration file
      #
      # @param config_file [String] The configuration file to load
      # @return [Hash] Configuration file contents
      #
      def load_config_file_section(config_file)
        config = load_config_file(config_file)

        return if nil_or_empty?(config)

        path = resource_config_path
        section_config = config.dig(*path)
        Chef::Log.debug("load_config_file_section: #{config_file} section #{path.join('|')} - [#{section_config.class}] #{section_config}")

        section_config
      end

      # Load a configuration item from a section on disk, the first match is returned
      #
      # @param config_file [String] The configuration file to load
      # @return [Hash] Configuration item contents
      #
      def load_config_file_section_item(config_file)
        config = load_config_file_section(config_file)

        return if nil_or_empty?(config)

        match = option_config_match.transform_keys { |k| translate_property_value(k) }
        Chef::Log.debug("load_config_file_section_item: Filtering on #{debug_var_output(match)} against #{debug_var_output(config)}")

        item = if accumulator_config_path_contained_nested?
                 option_config_path_match_key.map! { |k| translate_property_value(k) }
                 filter_tuple = option_config_path_match_key.zip(option_config_path_match_value, option_config_path_contained_key.slice(0...-1))
                 Chef::Log.trace("load_config_file_section_item: Zipped pairs #{debug_var_output(filter_tuple)}")

                 search_object = config
                 Chef::Log.trace("load_config_file_section_item: Initial search path set to #{debug_var_output(search_object)}")

                 while (k, v, ck = filter_tuple.shift)
                   Chef::Log.debug("load_config_file_section_item: Filtering for #{debug_var_output(k)} | #{debug_var_output(v)} | #{debug_var_output(ck)}")
                   search_object = search_object.select { |cs| cs[k].eql?(v) }
                   search_object = search_object.first.fetch(ck, nil) if ck

                   log_string = "load_config_file_section_item: Search path set to #{debug_var_output(search_object)} for #{k}, #{v}"
                   log_string.concat("and #{ck}") if ck
                   Chef::Log.trace(log_string)
                 end unless search_object.nil?

                 Chef::Log.debug("load_config_file_section_item: Resultant path #{debug_var_output(search_object)}")
                 search_object
               else
                 config.select { |cs| match.any? { |mk, mv| kv_test_log(cs, mk, mv) } }
               end

        Chef::Log.debug("load_config_file_section_item: Filtered items #{debug_var_output(item)}")

        raise unless item.one? || item.empty?
        item = item.first

        if item
          Chef::Log.info("load_config_file_section_item: #{config_file} match #{debug_var_output(match)}. Result #{debug_var_output(item)}")
        else
          Chef::Log.info("load_config_file_section_item: #{config_file} no match for #{debug_var_output(match)}")
        end

        item
      rescue KeyError
        nil
      end

      # Load a contained configuration item from a section on disk, the first match is returned
      #
      # @param config_file [String] The configuration file to load
      # @return [Hash] Contained configuration item contents
      #
      def load_config_file_section_contained_item(config_file)
        config = load_config_file_section_item(config_file)

        if nil_or_empty?(config)
          Chef::Log.warn('load_config_file_section_contained_item: Nil or empty config, returning')
          return
        end

        ck = accumulator_config_path_containing_key
        outer_key_config = config.fetch(ck, nil)
        if nil_or_empty?(outer_key_config)
          Chef::Log.warn('load_config_file_section_contained_item: Nil or empty outer_key_config, returning')
          return
        end

        match = option_config_match
        match.compact!
        match.transform_keys! { |k| translate_property_value(k) }
        Chef::Log.trace("load_config_file_section_contained_item: Filtering against K/V pairs #{debug_var_output(match)}")

        item = outer_key_config.filter { |object| match.any? { |k, v| kv_test_log(object, k, v) } }
        Chef::Log.info("load_config_file_section_contained_item: Filtered items #{debug_var_output(item)}")

        return if nil_or_empty?(item)

        unless item.one? || item.empty?
          Chef::Log.warn(
            "load_config_file_section_item: Expected either one or zero filtered configuration items, got #{item.count}. Data: #{debug_var_output(item)}"
          )
          raise Chef::Exceptions::CurrentValueDoesNotExist
        end

        item.first
      end

      # Error to raise when failing to filter a single containing resource from a parent path
      class FileConfigPathFilterError < FilterError; end
    end
  end
end
