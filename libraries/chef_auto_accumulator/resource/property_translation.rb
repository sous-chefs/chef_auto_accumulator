#
# Cookbook:: chef_auto_accumulator
# Library:: resource_property_translation
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

require_relative 'options'

module ChefAutoAccumulator
  module Resource
    # Methods for translating Chef property names to configuration file property names and vice-versa
    module PropertyTranslation
      private

      # Check if a resource property translation alias is defined and return the original property name
      # If an alias is not defined return the original property name
      #
      # @return [String] The (translated if required) property name
      #
      def translate_property_key(value)
        return unless value
        log_chef(:trace) { "Original value: #{value}" }

        result = if option_property_translation_matrix && option_property_translation_matrix.value?(value)
                   translated_value = option_property_translation_matrix.key(value)
                   log_chef(:debug) { "Translating #{value} -> #{translated_value}" }

                   translated_value
                 else
                   value
                 end.dup.to_s

        result.gsub!(*option_property_name_gsub.reverse) if option_property_name_gsub
        log_chef(:trace) { "Resultant value: #{result}" }

        result
      end

      # Check if a resource property translation alias is defined and return the translated config property name
      # If an alias is not defined return the original property name
      #
      # @return [String] The (translated if required) config property name
      #
      def translate_property_value(key)
        return unless key
        log_chef(:trace) { "Original key: #{key}" }

        result = if option_property_translation_matrix && option_property_translation_matrix.key?(key)
                   translated_key = option_property_translation_matrix.fetch(key)
                   log_chef(:debug) { "Translating #{key} -> #{translated_key}" }

                   translated_key
                 else
                   key
                 end.dup.to_s

        result.gsub!(*option_property_name_gsub) if option_property_name_gsub
        log_chef(:trace) { "Resultant key: #{result}" }

        result
      end
    end
  end
end
