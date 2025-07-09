#
# Cookbook:: chef_auto_accumulator
# Library:: state
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

require_relative 'config/accumulator'
require_relative 'config/file'
require_relative 'config/load_current_value'
require_relative 'config/path'

module ChefAutoAccumulator
  # State base module namespace
  module State
    STATE_CACHE_KEY = :ChefAutoAccumulator.freeze
    private_constant :STATE_CACHE_KEY

    private

    def run_state_cache(*keys)
      node.run_state[STATE_CACHE_KEY] ||= {}

      init_key = node.run_state[STATE_CACHE_KEY]
      keys.each do |k|
        log_chef(:debug) { "next test key: #{k}: #{nil_or_empty?(node.run_state[STATE_CACHE_KEY][k]) || !init_key.fetch(k, nil).is_a?(Hash)}" }

        unless nil_or_empty?(node.run_state[STATE_CACHE_KEY][k]) || !init_key.fetch(k, nil).is_a?(Hash)
          init_key = init_key[k]
          next
        end

        log_chef(:debug) { "Initialising state cache key: #{k}" }

        init_key[k] = {}
        init_key = init_key[k]
      end unless nil_or_empty?(keys)

      log_chef(:trace) { "State cache key: #{init_key}" }
      init_key
    end
  end
end
