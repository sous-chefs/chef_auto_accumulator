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
    def accumulator_config(action, key, value = nil)
      path = resource_config_path
      config_hash = accumulator_config_path_init(*path)

      Chef::Log.warn("Perfoming action #{action} on config key #{key}, value #{debug_var_output(value)} on path #{path.map { |p| "['#{p}']" }.join}")

      case action
      when :set
        config_hash[translate_property_value(key)] = value
      when :append
        config_hash[translate_property_value(key)] ||= ''
        config_hash[translate_property_value(key)].concat(value.to_s)
      when :push
        config_hash[translate_property_value(key)] ||= []
        config_hash[translate_property_value(key)].push(value)
      when :delete
        config_hash.delete(translate_property_value(key)) if config_hash.key?(translate_property_value(key))
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
                         Chef::Log.warn("init_config_template: Existing config load data: [#{existing_config_load.class}] #{existing_config_load}")

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
    def accumulator_config_path_init(*path)
      init_config_template unless config_template_exist?

      return config_file_template_content if path.all? { |p| p.is_a?(NilClass) } # Root path specified
      return config_file_template_content.dig(*path) if config_file_template_content.dig(*path).is_a?(Hash) # Return path if it exists

      Chef::Log.warn("accumulator_config_path_init: Initialising config file #{new_resource.config_file} path config#{path.map { |p| "['#{p}']" }.join}")
      config_hash = config_file_template_content
      path.each do |pn|
        config_hash[pn] ||= {}
        config_hash = config_hash[pn]
      end

      config_hash
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
