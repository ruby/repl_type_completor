# frozen_string_literal: true

source 'https://rubygems.org'

if ENV['GEMFILE_USE_PREINSTALLED_PRISM']
  # Preinstalled Prism is different from installed Prism. gem_dir is empty.
  gem 'rbs'
else
  # Specify your gem's dependencies in repl_type_completor.gemspec
  gemspec
end

gem 'irb', '>= 1.10.0'
gem 'rake', '~> 13.0'
gem 'test-unit'
gem 'test-unit-ruby-core'

if ENV['GEMFILE_PRISM_VERSION']
  if ENV['GEMFILE_PRISM_VERSION'] == 'latest'
    gem 'prism', github: 'ruby/prism'
  else
    gem 'prism', ENV['GEMFILE_PRISM_VERSION']
  end
end

if ENV['GEMFILE_RBS_VERSION']
  if ENV['GEMFILE_RBS_VERSION'] == 'latest'
    gem 'rbs', github: 'ruby/rbs'
  else
    gem 'rbs', ENV['GEMFILE_RBS_VERSION']
  end
end
