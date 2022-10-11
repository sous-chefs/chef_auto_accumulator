name 'chef_auto_accumulator'
maintainer 'Ben Hughes'
maintainer_email 'bmhughes@bmhughes.co.uk'
license 'Apache-2.0'
description 'Installs/Configures chef_auto_accumulator'
source_url 'https://github.com/bmhughes/chef_auto_accumulator'
issues_url 'https://github.com/bmhughes/chef_auto_accumulator/issues'
chef_version '>= 16.0'
version '0.3.0'

supports 'amazon'
supports 'centos'
supports 'debian'
supports 'fedora'
supports 'oracle'
supports 'redhat'
supports 'scientific'
supports 'ubuntu'

gem 'deepsort', '~> 0.4.5'
gem 'inifile', '~> 3.0'
gem 'toml-rb', '~> 2.0'
