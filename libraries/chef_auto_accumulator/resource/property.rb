#
# Cookbook:: chef_auto_accumulator
# Library:: resource_property
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

module ChefAutoAccumulator
  module Resource
    # Methods for accessing Chef resource properties automatically from both resource definition and action class
    module Property
      private

      def resource_property(name)
        value = if !action_class? && respond_to?(name)
                  send(name)
                elsif action_class? && new_resource.respond_to?(name)
                  new_resource.send(name)
                end
        log_chef(:trace) { "Got value for property #{name}: #{debug_var_output(value)}" }

        value
      end
    end
  end
end
