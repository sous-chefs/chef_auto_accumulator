#
# Cookbook:: chef_auto_accumulator
# Library:: file_yaml
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

require 'yaml'
require_relative '../_utils'

module ChefAutoAccumulator
  module File
    # Yaml file type read and write
    module YAML
      include ChefAutoAccumulator::Utils

      extend self

      # Load an YAML file from disk
      #
      # @param file [String] The file to load
      # @return [Hash] File contents
      #
      def load_file(file)
        return unless ::File.exist?(file)

        ::YAML.load(::File.read(file))
      end

      # Create a YAML file output as a String from a Hash
      #
      # @param content [Hash] The file contents as a Hash
      # @return [String] Formatted YAML output
      #
      def file_string(content, sort = true)
        raise ArgumentError, "Expected Hash got #{content.class}" unless content.is_a?(Hash)

        content_compact = content.dup.compact
        content_compact.deep_sort! if sort
        content_compact.delete_if(&HASH_DEEP_CLEAN)

        ::YAML.dump(content_compact)
      end
    end
  end
end
