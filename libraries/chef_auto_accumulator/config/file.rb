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
require_relative '../config'
require_relative '../resource'

require_relative '../resource/property'
require_relative '../resource/property_translation'

module ChefAutoAccumulator
  module Config

    # On disk configuration state access, required for load_current_value support
    class File
      include ChefAutoAccumulator::File
      include Config
      include Resource

      include ChefAutoAccumulator::Resource::Property
      include ChefAutoAccumulator::Resource::PropertyTranslation

      attr_reader :contents, :file, :filetype
      attr_accessor :new_resource

      def initialize(filetype: config_file_type, file: config_file, new_resource:)
        raise FileError, "Configuration file #{file} does not exist" unless ::File.exist?(file)

        @file = file
        @filetype = filetype
        @contents = nil
        @new_resource = new_resource

        true
      end

      def load!
        @contents = load_file(file, filetype)

        !nil_or_empty?(@contents)
      end

      # private

      # Load a section from the on disk configuration file
      #
      # @param config_file [String] The configuration file to load
      # @return [Hash] Configuration file contents
      #
      def file_section
        return if nil_or_empty?(@contents)

        path = resource_config_path
        section_config = @contents.dig(*path)
        log_chef(:debug) { "#{config_file} section #{path.join(' -> ')}\n#{debug_var_output(section_config, false)}" }
        log_chef(:trace) { "#{config_file} section #{path.join(' -> ')} data\n#{debug_var_output(section_config)}" }

        section_config
      end

      # Load a configuration item from a section on disk, the first match is returned
      #
      # @param config_file [String] The configuration file to load
      # @return [Hash] Configuration item contents
      #
      def file_section_item
        return if nil_or_empty?(file_section)

        match = option_config_match
        log_chef(:trace) { "Filter data\n#{debug_var_output(file_section)}" }

        item = if accumulator_config_path_contained_nested?
                 filter_tuple = option_config_path_match_key.zip(option_config_path_match_value, option_config_path_contained_key.slice(0...-1))
                 log_chef(:trace) { "Zipped pairs #{debug_var_output(filter_tuple)}" }

                 search_object = file_section
                 log_chef(:trace) { "Initial search path set to #{debug_var_output(search_object)}" }

                 while (k, v, ck = filter_tuple.shift)
                   log_chef(:debug) { "Filtering for #{debug_var_output(k)} | #{debug_var_output(v)} | #{debug_var_output(ck)}" }
                   break if search_object.nil?

                   search_object = search_object.select { |cs| cs[k].eql?(v) }
                   search_object = search_object.first.fetch(ck, nil) if ck

                   log_string = "Search path set to #{debug_var_output(search_object)} for #{k}, #{v}"
                   log_string.concat("and #{ck}") if ck
                   log_chef(:trace) { log_string }
                 end unless search_object.nil?

                 log_chef(:debug) { "Resultant path\n#{debug_var_output(search_object)}" }
                 search_object
               else
                 log_chef(:debug) { "Filtering\n#{debug_var_output(match)}\n\nagainst\n\n#{debug_var_output(file_section, true)}" }

                 index = config_item_index_match(file_section, match)
                 nil_or_empty?(index) ? nil : config.values_at(*index)
               end

        log_chef(:debug) { "Filtered items\n#{debug_var_output(item)}" }

        return if item.nil?

        raise "Expected one or no items to be filtered, got #{item.count}" unless item.one? || item.empty?

        if item
          log_chef(:info) { "#{@file} got match for Filter\n#{debug_var_output(match)}\n\nResult\n\n#{debug_var_output(item)}" }
        else
          log_chef(:info) { "#{@file} got no match for Filter\n#{debug_var_output(match)}" }
        end

        item.first
      rescue KeyError
        nil
      end

      # Load a contained configuration item from a section on disk, the first match is returned
      #
      # @param config_file [String] The configuration file to load
      # @return [Hash] Contained configuration item contents
      #
      def file_section_contained_item
        if nil_or_empty?(file_section_item)
          log_chef(:info) { 'Nil or empty config, returning' }
          return
        end

        ck = accumulator_config_path_containing_key
        outer_key_config = file_section_item.fetch(ck, nil)
        if nil_or_empty?(outer_key_config)
          log_chef(:info) { 'Nil or empty outer_key_config, returning' }
          return
        end

        match = option_config_match
        log_chef(:debug) { "Filtering against K/V pairs #{debug_var_output(match)}" }
        index = config_item_index_match(outer_key_config, match)
        item = nil_or_empty?(index) ? nil : outer_key_config.values_at(*index)

        if nil_or_empty?(item)
          log_chef(:info) { "#{@file} got No Match for Filter\n#{debug_var_output(match)}" }
          return
        else
          log_chef(:info) { "#{@file} got Match for Filter\n#{debug_var_output(match)}\nResult\n#{debug_var_output(item)}" }
        end

        log_chef(:warn) { "Expected either one or zero filtered configuration items, got #{item.count}. Data:\n#{debug_var_output(item)}" } unless item.one?

        item.first
      end

      # Test if a resources configuration is present on disk
      #
      # @return [true, false] Test result
      #
      def config_file_config_present?
        config = case option_config_path_type
                 when :array
                   load_config_file_section_item(new_resource.config_file)
                 when :array_contained
                   load_config_file_section_contained_item(new_resource.config_file)
                 when :hash
                   load_config_file_section(new_resource.config_file)
                 when :hash_contained
                   section = load_config_file_section(new_resource.config_file)
                   section.fetch(option_config_path_contained_key, nil) if section.is_a?(Hash)
                 end

        log_chef(:debug) { debug_var_output(config) }
        !config.nil?
      end

      # Match a configuration item against multiple conditions, return the highest matching element
      #
      # @param config [Array] The configuration set to search
      # @param match [Hash] The match criteria
      # @return [Any] Matched result
      #
      def config_item_index_match(config, match)
        return if nil_or_empty?(config)
        raise FileConfigPathFilterError, 'Empty resource match filter set' if nil_or_empty?(match)

        # Find the config items that match at least one of the match filters, then sort to bring the high matches to the top
        matched_items = config.each_with_index.map { |c, i| [i, match.map { |k, v| kv_test_log(c, k, v) }.count(true)] }.filter { |_, c| c.positive? }
        matched_items.sort_by! { |_, count| -count }

        return unless matched_items.count.positive?

        # Get the number of matches for the 'best' match then find out how many items matched at this level
        best_match = matched_items.first.last
        index = matched_items.filter { |_, c| c.eql?(best_match) }.map(&:first)

        unless index.one?
          log_chef(:warn) { "Expected either one or zero filtered configuration items, got #{index.count}. Data:\n#{debug_var_output(index)}" }
        end

        index
      end

      # Error to raise when failing to filter a single containing resource from a parent path
      class FileConfigPathFilterError < FilterError; end
    end

    # Error to raise when failing to filter a single containing resource from a parent path
    class ConfigFilePathFilterError < FilterError; end
  end
end
