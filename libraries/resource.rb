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
  module Resource
    include ChefAutoAccumulator::Config::File
    include ChefAutoAccumulator::Config::Path
    include ChefAutoAccumulator::File
    include ChefAutoAccumulator::Resource::Options
    include ChefAutoAccumulator::Resource::PropertyTranslation
    include ChefAutoAccumulator::Utils

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
      properties = instance_variable_defined?(:@new_resource) ? new_resource.class.properties(false).keys : self.class.properties(false).keys
      Chef::Log.debug("resource_properties: Got properties from resource: #{properties.join(', ')}")
      properties.reject! { |p| GLOBAL_CONFIG_PROPERTIES_SKIP.include?(p) }

      if option_config_properties_skip
        Chef::Log.debug("resource_properties: Resourced defined skip properties: #{skip_properties.join(', ')}")
        properties.reject! { |p| option_config_properties_skip.include?(p) }
      end

      Chef::Log.info("resource_properties: Filtered properties: #{properties.join(', ')}")
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
      config_path = accumulator_config_path_init(action, *path)

      log_string = ''
      log_string.concat("Perfoming action #{action} on ")
      log_string.concat("config key #{debug_var_output(key)}, ") if key
      log_string.concat("value #{debug_var_output(value)} on ") if value
      log_string.concat("path #{path.map { |p| "['#{p}']" }.join} #{debug_var_output(config_path)}")
      Chef::Log.warn(log_string)

      case action
      when :set
        config_path[translate_property_value(key)] = value
      when :append
        config_path[translate_property_value(key)] ||= ''
        config_path[translate_property_value(key)].concat(value.to_s)
      when :key_push
        config_path[translate_property_value(key)] ||= []
        config_path[translate_property_value(key)].push(value)
      when :key_delete
        config_path[translate_property_value(key)].delete(value)
      when :array_push
        config_path.push(value) unless config_path.include?(value)
      when :array_delete
        config_path.delete(value) if config_path.include?(value)
      when :delete
        config_path.delete(translate_property_value(key)) if config_path.key?(translate_property_value(key))
      else
        raise ArgumentError, "Unsupported accumulator config action #{action}"
      end
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
                         Chef::Log.info("init_config_template: Existing config load data: [#{existing_config_load.class}] #{existing_config_load}")

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

    # Initialise a Hash path for a configuration file template resources variables
    #
    # @param *path [String, Symbol, Array<String>, Array<Symbol>] The path to initialise
    # @return [Hash] The initialised Hash object
    #
    def accumulator_config_path_init(action, *path)
      init_config_template unless config_template_exist?

      return config_file_template_content if path.all? { |p| p.is_a?(NilClass) } # Root path specified

      # Return path if it exists
      existing_path = config_file_template_content.dig(*path)
      return existing_path if existing_path.is_a?(Array) || existing_path.is_a?(Hash)

      Chef::Log.debug("accumulator_config_path_init: Initialising config file #{new_resource.config_file} path config#{path.map { |p| "['#{p}']" }.join}")
      config_path = config_file_template_content
      path.each do |l|
        config_path[l] ||= if %i(array_push array_delete).include?(action) && l.eql?(path.last)
                             []
                           else
                             {}
                           end

        config_path = config_path[l]
      end

      config_path
    end

    # Return the relevant configuration file template resources variables configuration key
    #
    # @return [Hash] Config template variables
    #
    def config_file_template_content
      init_config_template unless config_template_exist?
      find_resource!(:template, new_resource.config_file).variables[:content]
    end
  end
end