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

      # Check if a resource property translation alias is defined and return the original property name
      # If an alias is not defined return the original property name
      #
      # @return [String] The (translated if required) property name
      #
      def translate_property_key(value)
        return unless value
        return option_property_translation_matrix.key(value) if option_property_translation_matrix &&
                                                                option_property_translation_matrix.value?(value)

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
        return unless key
        return option_property_translation_matrix.fetch(key) if option_property_translation_matrix &&
                                                                option_property_translation_matrix.key?(key)

        if option_property_name_gsub
          key.to_s.gsub(*option_property_name_gsub)
        else
          key.to_s
        end
      end
    end
  end
end
