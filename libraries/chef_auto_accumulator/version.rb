#
# Cookbook:: chef_auto_accumulator
# Library:: version
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
  cookbook_metadata = Chef::Cookbook::Metadata.new
  cookbook_metadata.from_file("#{__dir__.gsub('libraries/chef_auto_accumulator', '')}/metadata.rb")

  # Library version, taken from the cookbook metadata
  VERSION = cookbook_metadata.version.dup.freeze
  Chef::Log.warn("ChefAutoAccumulator v#{VERSION} loaded.")
end
