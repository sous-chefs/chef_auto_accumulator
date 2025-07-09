#
# Cookbook:: chef_auto_accumulator
# Library:: error
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

# Base namespace
module ChefAutoAccumulator
  # Base error class
  class BaseError < StandardError
    include ChefAutoAccumulator::Utils
  end

  class FilterError < BaseError
    def initialize(fkey, fvalue, path, result)
      super([
        "Failed to filter a single value for key #{debug_var_output(fkey)} and value #{debug_var_output(fvalue)}.",
        "Result: #{result.count} #{debug_var_output(result)}",
        "Path: #{debug_var_output(path, false)}",
      ].join("\n\n"))
    end
  end
end
