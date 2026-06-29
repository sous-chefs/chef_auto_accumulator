# frozen_string_literal: true

name 'chef_auto_accumulator'

run_list 'test::default'

cookbook 'chef_auto_accumulator', path: '.'
cookbook 'test', path: './test/cookbooks/test'
