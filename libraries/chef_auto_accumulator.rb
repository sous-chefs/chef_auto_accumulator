#
# Cookbook:: chef_auto_accumulator
# Library:: chef_auto_accumulator
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

require_relative 'chef_auto_accumulator/version'
require_relative 'chef_auto_accumulator/_utils'
require_relative 'chef_auto_accumulator/error'

require_relative 'chef_auto_accumulator/config'
require_relative 'chef_auto_accumulator/file'
require_relative 'chef_auto_accumulator/resource'

# Base namespace to include for automatic accumulator functionality
module ChefAutoAccumulator
  include ChefAutoAccumulator::Config
  include ChefAutoAccumulator::File
  include ChefAutoAccumulator::Resource
  include ChefAutoAccumulator::Utils
end
