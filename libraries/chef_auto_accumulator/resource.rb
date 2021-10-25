#
# Cookbook:: chef_auto_accumulator
# Library:: resource
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

require_relative '_utils'
require_relative 'config'
require_relative 'file'

require_relative 'resource/options'
require_relative 'resource/property_translation'

module ChefAutoAccumulator
  # Module for inclusion in automatic accumulator resources
  module Resource
    include ChefAutoAccumulator::Resource::Options
    include ChefAutoAccumulator::Resource::PropertyTranslation

    # List of properties to skip for all resources
    GLOBAL_CONFIG_PROPERTIES_SKIP = %i(
      config_directory
      config_file
      load_existing_config_file
      cookbook
      source
      owner
      group
      filemode
      sensitive
      extra_options
    ).freeze
    private_constant :GLOBAL_CONFIG_PROPERTIES_SKIP

    private

    # Enumerate the properties of the including resource
    # Properties are skipped globally via the constant GLOBAL_CONFIG_PROPERTIES_SKIP
    # Properties are skipped per-resource via the :resource_option_config_properties_skip method if it is defined
    #
    # @return [Array] list of resource properties
    #
    def resource_properties
      properties = action_class? ? new_resource.class.properties(false).keys : self.class.properties(false).keys
      Chef::Log.trace("resource_properties: Got properties from resource: #{properties.sort.join(', ')}")
      properties.reject! { |p| GLOBAL_CONFIG_PROPERTIES_SKIP.include?(p) }

      if option_config_properties_skip
        Chef::Log.trace("resource_properties: Resourced defined skip properties: #{option_config_properties_skip.join(', ')}")
        properties.reject! { |p| option_config_properties_skip.include?(p) }
      end

      Chef::Log.debug("resource_properties: Resultant filtered properties for #{resource_type_name}: #{properties.sort.join(', ')}")
      properties
    end

    # Add/remove/overwrite/delete accumulator config values
    #
    # @param action [Symbol] Config action to perform
    # @param key [String, Symbol] The key to manipulate
    # @param value [any] Value to assign to key
    # @return [nil]
    #
    def accumulator_config(action:, key: nil, value: nil)
      path = resource_config_path
      config_path = case option_config_path_type
                    when :hash, :hash_contained, :array
                      accumulator_config_path_init(action, *path)
                    when :array_contained
                      accumulator_config_containing_path_init(action: action, path: path)
                    else
                      raise ArgumentError, "Unknown config path type #{debug_var_output(option_config_path_type)}"
                    end

      log_string = ''
      log_string.concat("Perfoming action #{action} on ")
      log_string.concat("config key #{debug_var_output(key)}, ") if key
      log_string.concat("value #{debug_var_output(value)} on ") if value
      log_string.concat("path #{path.map { |p| "['#{p}']" }.join} #{debug_var_output(config_path)}")
      Chef::Log.info(log_string)

      case action
      when :set
        config_path[translate_property_value(key)] = value
      when :append
        config_path[translate_property_value(key)] ||= ''
        config_path[translate_property_value(key)].concat(value.to_s)
      when :key_push
        config_path[translate_property_value(key)] ||= []

        unless config_path[translate_property_value(key)].include?(value) && accumulator_config_array_index.one?
          accumulator_config_array_index.each { |i| config_path[translate_property_value(key)].delete_at(i) } if accumulator_config_array_present?
          config_path[translate_property_value(key)].push(value)
        end
      when :key_delete
        config_path[translate_property_value(key)] ||= []
        accumulator_config_array_index.each { |i| config_path[translate_property_value(key)].delete_at(i) } if accumulator_config_array_present?
      when :key_delete_match
        config_path[translate_property_value(key)] ||= []
        config_path[translate_property_value(key)].delete_if { |v| v[translate_property_value(option_config_match_key)].eql?(option_config_match_value) }
      when :array_push
        unless config_path.include?(value) && accumulator_config_array_index.one?
          accumulator_config_array_index.each { |i| config_path.delete_at(i) } if accumulator_config_array_present?
          config_path.push(value)
        end
      when :array_delete
        accumulator_config_array_index.each { |i| config_path[translate_property_value(key)].delete_at(i) } if accumulator_config_array_present?
      when :array_delete_match
        config_path.delete_if { |v| v[translate_property_value(key)].eql?(value) }
      when :delete
        config_path.delete(translate_property_value(key)) if accumulator_config_present?(translate_property_value(key))
      else
        raise ArgumentError, "Unsupported accumulator config action #{action}"
      end
    end

    # Get the index for the configuration item within an Array if it exists
    #
    # @return [Integer, nil]
    #
    def accumulator_config_array_index
      path = resource_config_path
      index = case option_config_path_type
              when :array
                key = translate_property_value(option_config_path_match_key)
                value = option_config_path_match_value

                Chef::Log.debug("accumulator_config_array_present?: Testing :array for #{debug_var_output(key)} | #{debug_var_output(value)}")

                array_path = accumulator_config_path_init(action, *path)
                array_path.each_index.select { |i| array_path[i][translate_property_value(key)].eql?(value) }
              when :array_contained
                key = translate_property_value(option_config_match_key)
                value = option_config_match_value
                ck = accumulator_config_path_contained_nested? ? option_config_path_contained_key.last : option_config_path_contained_key

                Chef::Log.debug("accumulator_config_array_present?: Testing :contained_array #{debug_var_output(ck)} for #{debug_var_output(key)} | #{debug_var_output(value)}")

                array_cpath = accumulator_config_containing_path_init(action: action, path: path).fetch(ck, [])
                array_cpath.each_index.select { |i| array_cpath[i][key].eql?(value) }
              else
                raise ArgumentError "Unknown config path type #{debug_var_output(option_config_path_type)}"
              end

      index.reverse! # We need the indexes in reverse order so we delete correctly, otherwise the shift will result in left over objects we wanted to delete
      Chef::Log.debug("accumulator_config_array_index: Result #{debug_var_output(index)}")

      index
    end

    # Check if a given Array configuration path contains the configuration for this resource
    #
    # @return [true, false]
    #
    def accumulator_config_array_present?
      result = !accumulator_config_array_index.nil?
      Chef::Log.debug("accumulator_config_array_present?: Result #{debug_var_output(result)}")

      result
    end

    # Check if a given configuration path contains the configuration for this resource
    #
    # @return [true, false]
    #
    def accumulator_config_present?(key)
      accumulator_config_path_init(action, *resource_config_path).key?(translate_property_value(key))
    end

    # Check if a given configuration file template resource exists
    #
    # @return [true, false]
    #
    def config_template_exist?
      Chef::Log.debug("config_template_exist?: Checking for config file template #{new_resource.config_file}")
      config_resource = !find_resource!(:template, ::File.join(new_resource.config_file)).nil?

      Chef::Log.debug("config_template_exist?: #{config_resource}")
      config_resource
    rescue Chef::Exceptions::ResourceNotFound
      Chef::Log.debug("config_template_exist?: Config file template #{new_resource.config_file} ResourceNotFound")
      false
    end

    # Initialise a configuration file template resource
    #
    # @return [true, false] Template creation result
    #
    def init_config_template
      return false if config_template_exist?

      Chef::Log.info("init_config_template: Creating config template resource for #{new_resource.config_file}")

      config_content = if new_resource.load_existing_config_file
                         existing_config_load = load_config_file(new_resource.config_file) || {}
                         Chef::Log.debug("init_config_template: Existing config load data: [#{existing_config_load.class}] #{existing_config_load}")

                         existing_config_load
                       else
                         {}
                       end

      with_run_context(:root) do
        declare_resource(:chef_gem, 'deepsort') { compile_time true } unless gem_installed?('deepsort')
        declare_resource(:chef_gem, 'inifile') { compile_time true } unless gem_installed?('inifile')
        declare_resource(:chef_gem, 'toml-rb') { compile_time true } unless gem_installed?('toml-rb')

        declare_resource(:template, new_resource.config_file) do
          source new_resource.source
          cookbook new_resource.cookbook

          owner new_resource.owner
          group new_resource.group
          mode new_resource.filemode

          sensitive new_resource.sensitive

          variables({
            content: config_content,
            file_type: config_file_type,
          })

          helpers(ChefAutoAccumulator::File)

          action :nothing
          delayed_action :create
        end
      end

      true
    end

    # Initialise a path for a configuration file template resources variables
    #
    # @param action [Symbol] The configuration action being performed
    # @param path [String, Symbol, Array<String>, Array<Symbol>] The path to initialise
    # @return [Hash, Array] The initialised config container object
    #
    def accumulator_config_path_init(action, *path)
      init_config_template unless config_template_exist?

      return config_file_template_content if path.all? { |p| p.is_a?(NilClass) } # Root path specified

      # Return path if it exists
      existing_path = config_file_template_content.dig(*path)
      return existing_path if existing_path.is_a?(Array) || existing_path.is_a?(Hash)

      Chef::Log.info("accumulator_config_path_init: Initialising config file #{new_resource.config_file} path config#{path.map { |p| "['#{p}']" }.join}")
      config_path = config_file_template_content
      path.each do |l|
        config_path[l] ||= if %i(array_push array_delete key_push key_delete).include?(action) && l.eql?(path.last)
                             []
                           else
                             {}
                           end

        config_path = config_path[l]
      end

      config_path
    end

    # Initialise and return a containing path object, for when a configuration item is contained within another
    #
    # @param action [Symbol] Action to perform
    # @param filter_key [String, Symbol] The Hash key to filter on
    # @param filter_value [any] The value to filter against
    # @param path [String, Symbol, Array<String>, Array<Symbol>] The path to initialise
    # @return [Hash] The initialised Hash object
    #
    def accumulator_config_containing_path_init(
      action:,
      filter_key: option_config_path_match_key,
      filter_value: option_config_path_match_value,
      containing_key: option_config_path_contained_key,
      path:
    )
      raise ArgumentError, "Path must be specified as Array, got #{debug_var_output(path)}" unless path.is_a?(Array)

      # Initialise the parent path as normal
      parent_path = accumulator_config_path_init(action, *path)
      Chef::Log.debug("accumulator_config_containing_path_init: Got parent path #{debug_var_output(parent_path)}")
      return parent_path if path.all? { |p| p.is_a?(NilClass) } # Root path specified. Do we need this?

      if accumulator_config_path_contained_nested?
        filter_tuple = filter_key.zip(filter_value, containing_key.slice(0...-1))
        Chef::Log.debug("accumulator_config_containing_path_init: Zipped pairs #{debug_var_output(filter_tuple)}")
        search_object = parent_path
        Chef::Log.debug("accumulator_config_containing_path_init: Initial search path set to #{debug_var_output(search_object)}")

        while (k, v, ck = filter_tuple.shift)
          search_object = accumulator_config_path_filter(search_object, k, v)
          search_object = search_object.fetch(ck) if ck
          Chef::Log.debug("accumulator_config_containing_path_init: Search path set to #{debug_var_output(search_object)} for #{k} | #{v} | #{ck}")
        end

        Chef::Log.debug("accumulator_config_containing_path_init: Resultant path #{debug_var_output(search_object)}")
        search_object
      else

        # Find the object that matches the filter
        accumulator_config_path_filter(parent_path, filter_key, filter_value)
      end
    end

    # Filter a configuration item object collection by a key value pair
    #
    # @param path [Hash, Array] Collection to filter
    # @param filter_key [String, Symbol] Key to filter on
    # @param filter_value [Any] Value to filter for
    # @return [Hash] Object for which the filter matches
    #
    def accumulator_config_path_filter(path, filter_key, filter_value)
      raise "The contained parent path should respond to :filter, class #{path.class} does not" unless path.respond_to?(:filter)

      Chef::Log.debug("accumulator_config_path_filter: Filtering #{debug_var_output(path)} on #{debug_var_output(filter_key)} | #{debug_var_output(filter_value)}")
      filtered_object = path.filter { |v| v[filter_key].eql?(filter_value) }

      Chef::Log.debug("accumulator_config_path_filter: Got filtered value #{debug_var_output(filtered_object)}")
      raise AccumlatorConfigPathFilterError.new(filter_key, filter_value, path, filtered_object) unless filtered_object.one?

      filtered_object.first
    end

    # Return the relevant configuration file template resources variables configuration key
    #
    # @return [Hash] Config template variables
    #
    def config_file_template_content
      init_config_template unless config_template_exist?
      find_resource!(:template, new_resource.config_file).variables[:content]
    end

    # Error to raise when failing to filter a single containing resource from a parent path
    class AccumlatorConfigPathFilterError < BaseError
      include ChefAutoAccumulator::Utils

      def initialize(fkey, fvalue, path, result)
        super([
          "Failed to filter a single value for key #{debug_var_output(fkey)} and value #{debug_var_output(fvalue)}.",
          "Result: #{result.count} #{debug_var_output(result)}",
          "Path: #{debug_var_output(path)}",
        ].join("\n\n"))
      end
    end
  end
end
