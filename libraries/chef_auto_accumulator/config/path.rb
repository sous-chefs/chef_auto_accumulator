#
# Cookbook:: chef_auto_accumulator
# Library:: config_path
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

require_relative '../resource/options'

module ChefAutoAccumulator
  module Config
    # Accumulated config path access
    module Path
      private

      # Get the default configuration path for the relevant resource
      #
      # @return [String, Array<String>] Default configuration path for resource
      #
      def resource_default_config_path
        type_string = resource_type_name
        strip_regex = if option_config_base_path
                        Regexp.new(option_config_base_path)
                      else
                        ''
                      end

        config_path = Array(type_string.gsub(strip_regex, '').split('_').join('.'))

        log_chef(:debug) { "Generated config path #{config_path}" }
        raise if nil_or_empty?(config_path)

        config_path
      end

      # Get the actual configuration path for the relevant resource
      #
      # @return [String, Array<String>] Actual configuration path for resource
      #
      def resource_config_path
        return resource_default_config_path unless option_config_path_override

        option_config_path_override
      end
    end
  end
end
