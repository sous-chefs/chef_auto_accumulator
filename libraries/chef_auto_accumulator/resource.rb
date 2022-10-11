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
require_relative 'resource/property'
require_relative 'resource/property_translation'

module ChefAutoAccumulator
  # Module for inclusion in automatic accumulator resources
  module Resource
    include ChefAutoAccumulator::Resource::Options
    include ChefAutoAccumulator::Resource::Property
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
      force_replace
      clean_nil_values
    ).freeze

    FILE_SUPPORTING_GEMS = %w(deepsort inifile toml-rb).freeze

    private_constant :GLOBAL_CONFIG_PROPERTIES_SKIP, :FILE_SUPPORTING_GEMS

    private

    # Enumerate the properties of the including resource
    # Properties are skipped globally via the constant GLOBAL_CONFIG_PROPERTIES_SKIP
    # Properties are skipped per-resource via the :resource_option_config_properties_skip method if it is defined
    #
    # @return [Array] list of resource properties
    #
    def resource_properties
      properties = action_class? ? new_resource.class.properties(false).keys : self.class.properties(false).keys
      log_chef(:trace) { "Got properties from resource: #{properties.sort.join(', ')}" }
      properties.reject! { |p| GLOBAL_CONFIG_PROPERTIES_SKIP.include?(p) }

      if option_config_properties_skip
        log_chef(:trace) { "Resourced defined skip properties: #{option_config_properties_skip.join(', ')}" }
        properties.reject! { |p| option_config_properties_skip.include?(p) }
      end

      log_chef(:debug) { "Resultant filtered properties for #{resource_type_name}: #{properties.sort.join(', ')}" }
      properties
    end

    # Return a Hash of the resources set property key/values
    #
    # @return [Hash] Hash map of resource property key/values
    #
    def resource_properties_map
      map = resource_properties.map { |rp| [translate_property_value(rp), new_resource.send(rp)] }.to_h
      map.compact! unless option_permit_nil_properties

      log_chef(:info) { "Property map for #{resource_type_name}: #{debug_var_output(map)}" }
      map
    end

    # Add/remove/overwrite/delete accumulator config values
    #
    # @param action [Symbol] Config action to perform
    # @param key [String, Symbol] The key to manipulate
    # @param value [any] Value to assign to key
    # @param force_replace [TrueClass, FalseClass] Force replacement of the configuration object
    # @return [Array, Hash] The resultant configuration
    #
    def accumulator_config(action:, key: nil, value: nil, force_replace: false)
      path = resource_config_path
      config_path = case option_config_path_type
                    when :hash, :hash_contained, :array
                      accumulator_config_path_init(action, *path)
                    when :array_contained
                      accumulator_config_containing_path_init(action: action, path: path)
                    else
                      raise ArgumentError, "Unknown config path type #{debug_var_output(option_config_path_type)}"
                    end
      config_key = translate_property_value(key) if key

      log_string = ''
      log_string.concat("\nPerfoming action :#{action} on configuration ")
      log_string.concat("Path: #{path.join(' -> ')}\n#{debug_var_output(config_path)}\n")
      log_string.concat("Key:\n\t#{debug_var_output(config_key)}\n") if key
      log_string.concat("Value:\n\t#{debug_var_output(value)}\n") if value
      log_chef(:info) { log_string }

      ###
      ## Array Sub-Action
      ###
      push_action = if !accumulator_config_array_present?
                      # Create
                      log_chef(:info) { "Create Array and push #{value}" }
                      :create
                    elsif accumulator_config_array_present? && accumulator_config_array_index.one? && value.respond_to?(:merge) && !force_replace
                      # Merge with existing
                      log_chef(:info) { "Merge #{value} with existing" }
                      :merge
                    elsif (accumulator_config_array_present? && (accumulator_config_array_index.count > 1)) || force_replace
                      # Replace (remove duplicates if present)
                      log_chef(:warn) do
                        "Found #{accumulator_config_array_index.count} duplicate pre-existing configuration items for\n#{debug_var_output(value)}, " \
                        "clearing and replacing duplicates at indexes #{debug_var_output(accumulator_config_array_index)}"
                      end
                      :replace
                    else
                      raise 'Unknown push_action state'
                    end if %i(key_push array_push).include?(action)

      ###
      ## Config action
      ###
      case action
      ###
      ## Hash config_path
      ###
      when :set
        # config_path is a Hash
        config_path[config_key] = value
      when :delete
        # config_path is a Hash
        config_path.delete(config_key) if config_path.key?(config_key)
      when :append
        # config_path is a Hash with a String key
        config_path[config_key] ||= ''
        config_path[config_key].concat(value.to_s) unless config_path[config_key].match?(value)
      when :key_push
        # config_path is an Hash with an Array key
        case push_action
        when :create
          config_path[config_key] ||= []
          config_path[config_key].push(value)
        when :merge
          index = accumulator_config_array_index.pop
          config_path[config_key][index].merge!(value)
        when :replace
          accumulator_config_array_index.each { |i| config_path[config_key].delete_at(i) }
          config_path[config_key].push(value)
        end
      when :key_delete
        # config_path is an Hash with an Array key
        # Delete matched indexes from key, immediately return if the path is nil or empty
        return if nil_or_empty?(config_path[config_key])
        accumulator_config_array_index.each { |i| config_path[config_key].delete_at(i) } if accumulator_config_array_present?
      when :key_delete_match_self
        # config_path is an Hash with an Array key
        # Delete indexes that match the current resource config, immediately return if the path is nil or empty
        return if nil_or_empty?(config_path)
        option_config_match.each { |k, v| config_path[config_key].delete_if { |kdm| kdm[k].eql?(v) } }
      ###
      ## Array config_path
      ###
      when :array_push
        # config_path is an Array
        case push_action
        when :create
          config_path.push(value)
        when :merge
          index = accumulator_config_array_index.pop
          config_path[index].merge!(value)
        when :replace
          accumulator_config_array_index.each { |i| config_path.delete_at(i) }
          config_path.push(value)
        end
      when :array_delete
        # config_path is an Array
        accumulator_config_array_index.each { |i| config_path.delete_at(i) } if accumulator_config_array_present?
      else
        raise ArgumentError, "Unsupported accumulator config action #{action}"
      end

      # Return and log resultant configuration
      resultant_config = if key
                           config_path[config_key]
                         else
                           config_path
                         end

      log_chef(:debug) { "Resultant configuration #{debug_var_output(resultant_config)}" }

      resultant_config
    end

    # Get the index for the configuration item within an Array if it exists
    #
    # @return [Integer, nil]
    #
    def accumulator_config_array_index
      # Get the path and match config for the resource applying any property translations
      path = resource_config_path
      match = option_config_match

      # Find the Array index for the configuration object that matches the resource definition
      index = case option_config_path_type
              when :array
                log_chef(:debug) { "Testing :array for #{debug_var_output(match)}" }

                array_path = accumulator_config_path_init(action, *path)
                array_path.each_with_index.select { |obj, _| match.any? { |k, v| kv_test_log(obj, k, v) } }.map(&:last)
              when :array_contained
                ck = accumulator_config_path_containing_key

                log_chef(:debug) { "Searching :array_contained #{debug_var_output(ck)} against #{debug_var_output(match)}" }

                array_cpath = accumulator_config_containing_path_init(action: action, path: path)
                return unless array_cpath

                # Fetch the containing key and filter for any objects that match the filter
                array_cpath.fetch(ck, []).each_with_index.select { |obj, _| match.any? { |k, v| kv_test_log(obj, k, v) } }.map(&:last)
              else
                raise ArgumentError "Unknown config path type #{debug_var_output(option_config_path_type)}"
              end

      index.reverse! # We need the indexes in reverse order so we delete correctly, otherwise the shift will result in left over objects we intended to delete
      log_chef(:debug) { "Result #{debug_var_output(index)}" }

      index
    end

    # Check if a given Array configuration path contains the configuration for this resource
    #
    # @return [true, false]
    #
    def accumulator_config_array_present?
      result = !nil_or_empty?(accumulator_config_array_index)
      log_chef(:debug) { "Result #{debug_var_output(result)}" }

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
      log_chef(:debug) { "Checking for config file template #{new_resource.config_file}" }
      config_resource = !find_resource!(:template, ::File.join(new_resource.config_file)).nil?

      log_chef(:debug) { debug_var_output(config_resource) }
      config_resource
    rescue Chef::Exceptions::ResourceNotFound
      log_chef(:debug) { "Config file template #{new_resource.config_file} ResourceNotFound" }
      false
    end

    # Initialise a configuration file template resource
    #
    # @return [true, false] Template creation result
    #
    def init_config_template
      return false if config_template_exist?

      log_chef(:info) { "Creating config template resource for #{new_resource.config_file}" }

      config_content = if new_resource.load_existing_config_file
                         existing_config_load = load_config_file(new_resource.config_file, false) || {}
                         log_chef(:debug) { "Existing config load data: #{debug_var_output(existing_config_load)}" }

                         existing_config_load
                       else
                         {}
                       end

      with_run_context(:root) do
        FILE_SUPPORTING_GEMS.each { |gem| declare_resource(:chef_gem, gem) { compile_time true } unless gem_installed?(gem) }

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

    # Initialise a path for a configuration resources properties
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

      log_chef(:info) { "Initialising config file #{new_resource.config_file} path config#{path.map { |p| "['#{p}']" }.join}" }
      config_path = config_file_template_content
      path.each do |l|
        config_path[l] ||= if %i(array_push array_delete key_push key_delete key_delete_match_self).include?(action) && l.eql?(path.last)
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

      # Initialise the parent path
      parent_path = accumulator_config_path_init(action, *path)
      log_chef(:debug) { "Got parent path type #{debug_var_output(parent_path, false)} at #{debug_var_output(path, false)}" }
      log_chef(:trace) { "Parent path data\n#{debug_var_output(parent_path)}" }

      if path.all? { |p| p.is_a?(NilClass) } # Root path specified. Do we need this here?
        log_chef(:warn) { "!!! Root path specified for path #{debug_var_output(path)}. Do we need this here?" }
        return parent_path
      end

      if accumulator_config_path_contained_nested?
        filter_tuple = filter_key.zip(filter_value, containing_key.slice(0...-1))
        log_chef(:debug) { "Zipped search tuples\n#{debug_var_output(filter_tuple)}" }

        # Set the initial search path
        search_object = parent_path

        while (k, v, ck = filter_tuple.shift)
          search_path_log = "Searching path #{debug_var_output(search_object)} for Key: #{debug_var_output(k)} | Value: #{debug_var_output(v)}"
          search_path_log.concat(" | Containing Key: #{debug_var_output(ck)}") if ck
          log_chef(:info) { search_path_log }

          break if search_object.nil?

          # Filter the containing Array objects
          search_object = accumulator_config_path_filter(search_object, k, v)
          if search_object.nil?
            log_chef(:info) { "Got a nil search object for #{debug_var_output(k)} | #{debug_var_output(v)}, breaking" }
            break
          end

          # Fetch the containing key
          search_object = search_object.fetch(ck) if ck && !search_object.nil?
        end

        log_chef(:debug) { "Resultant path\n#{debug_var_output(search_object)}" }
        search_object
      else
        # Find the object that matches the filter
        accumulator_config_path_filter(parent_path, filter_key, filter_value)
      end
    rescue NameError, KeyError => e
      raise AccumlatorConfigNoParentPathError.new(e, resource_declared_name, resource_type_name, k, v, ck, search_object)
    end

    # Filter a configuration item object collection by a key value pair
    #
    # @param path [Hash, Array] Collection to filter
    # @param key [String, Symbol] Key to filter on
    # @param value [Any] Value to filter for
    # @return [Hash] Object for which the filter matches
    #
    def accumulator_config_path_filter(path, key, value)
      raise "The contained parent path should respond to :filter, class #{path.class} does not" unless path.respond_to?(:filter)

      log_chef(:debug) { "Filtering #{debug_var_output(path, false)} on #{debug_var_output(key)} | #{debug_var_output(value)}" }
      log_chef(:trace) { "Path data\n#{debug_var_output(path)}" }
      filtered_object = path.filter { |v| v[key].eql?(value) }

      return if filtered_object.empty?

      log_chef(:debug) { "Got filtered value #{debug_var_output(filtered_object, false)}" }
      log_chef(:trace) { "Filtered value data\n#{debug_var_output(filtered_object)}" }
      raise AccumlatorConfigPathFilterError.new(key, value, path, filtered_object) unless filtered_object.one?

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
    class AccumlatorConfigPathFilterError < FilterError; end

    # Error to raise when a parent containing object does not exist
    class AccumlatorConfigNoParentPathError < BaseError
      def initialize(error, name, type, k, v, ck, path)
        error_msg = "Failed to find a parent containing object for #{type}[#{name}]\n"
        error_msg << case error
                     when NameError
                       "Got NameError when Filtering object #{debug_var_output(path)} for"\
                       "Key: #{debug_var_output(k)}, Value: #{debug_var_output(v)}\n"
                     when KeyError
                       "Got KeyError when fetching Containing Key: #{debug_var_output(ck)} from object\n"\
                       "\n#{debug_var_output(path)}\n"\
                       'Does the parent containing configuration resource exist?'
                     else
                       "Unknown error #{error.class} occured"
                     end

        super(Array(error_msg).join("\n"))
      end
    end
  end
end
