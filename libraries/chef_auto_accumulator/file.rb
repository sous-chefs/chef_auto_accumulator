#
# Cookbook:: chef_auto_accumulator
# Library:: file
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

require 'deepsort'
require_relative '_utils'

require_relative 'file/ini'
require_relative 'file/json'
require_relative 'file/toml'
require_relative 'file/yaml'

module ChefAutoAccumulator
  # On disk configuration file properties and access
  module File
    extend ChefAutoAccumulator::Utils
    include ChefAutoAccumulator::Utils

    # Supported file types
    SUPPORTED_TYPES = %i(INI JSON JSONC TOML YAML).freeze

    # Enumerable deep clean proc
    ENUM_DEEP_CLEAN = proc do |*args|
      v = args.last
      v.delete_if(&ENUM_DEEP_CLEAN) if v.respond_to?(:delete_if)
      nil_or_empty?(v) && !v.is_a?(String)
    end

    # Get the specified file type from the resource options
    #
    # @return [Symbol] The configured file type
    #
    def config_file_type
      type = option_config_file_type
      raise ArgumentError, "Unsupported file type #{debug_var_output(type)}" unless SUPPORTED_TYPES.include?(type)
      log_chef(:debug) { "Config file type '#{type}'" }

      type
    end

    # Get the default template for the file type
    #
    # @return [String] Template file name
    #
    def config_file_template_default
      template = case config_file_type
                 when :JSON
                   'file_bare.erb'
                 when :INI, :JSONC, :TOML, :YAML
                   'file.erb'
                 else
                   raise ArgumentError, "Unsupported file type #{debug_var_output(type)}"
                 end
      log_chef(:debug) { "Config file template '#{template}'" }

      template
    end

    # Load a file from disk
    #
    # @param file [String] The file to load
    # @param type [Symbol] The file type to load
    # @return [Hash] File contents
    #
    def load_file(file, type = config_file_type)
      log_chef(:debug) { "Sending :load_file to module #{type} with file #{file}" }

      ChefAutoAccumulator::File.const_get(type).send(:load_file, file)
    end

    # Save a file to disk
    #
    # @param file [String] The file path on disk to save
    # @param type [Symbol] The file type to save
    # @return [String] Formatted output
    #
    def save_file(file, type = config_file_type)
      log_chef(:debug) { "Sending :save_file to module #{type} with file #{file}" }

      ChefAutoAccumulator::File.const_get(type).send(:file_string, file)
    end
  end
end
