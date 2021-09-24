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
    module PropertyTranslation
      private

      # Get the actual property translation matrix for the resource (if defined)
      #
      # @return [Hash] Property translation matrix
      #
      def property_translation_matrix
        translation_matrix = if !action_class? && respond_to?(:resource_config_properties_translate)
                               resource_config_properties_translate
                             elsif action_class? && new_resource.respond_to?(:resource_config_properties_translate)
                               new_resource.resource_config_properties_translate
                             end

        return unless translation_matrix

        raise "The property translation matrix should be defined as a Hash, got #{translation_matrix.class}" unless translation_matrix.is_a?(Hash)

        translation_matrix
      end

      # Check if a resource property translation alias is defined and return the original property name
      # If an alias is not defined return the original property name
      #
      # @return [String] The (translated if required) property name
      #
      def translate_property_key(value)
        return property_translation_matrix.key(value) if property_translation_matrix &&
                                                         property_translation_matrix.value?(value)

        if option_property_name_gsub
          value.to_s.gsub(*option_property_name_gsub.reverse)
        else
          value.to_s
        end
      end

      # Check if a resource property translation alias is defined and return the translated config property name
      # If an alias is not defined return the original property name
      #
      # @return [String] The (translated if required) config property name
      #
      def translate_property_value(key)
        return property_translation_matrix.fetch(key) if property_translation_matrix &&
                                                         property_translation_matrix.key?(key)

        if option_property_name_gsub
          key.to_s.gsub(*option_property_name_gsub)
        else
          key.to_s
        end
      end
    end
  end
end
