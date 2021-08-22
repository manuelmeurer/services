lib = File.expand_path('../lib', __FILE__)

unless $LOAD_PATH.include?(lib)
  $LOAD_PATH.unshift(lib)
end

require 'services/version'

Gem::Specification.new do |gem|
  files      = `git ls-files`.split($/)
  test_files = files.grep(%r(^spec/))

  gem.name                  = 'services'
  gem.version               = Services::VERSION
  gem.platform              = Gem::Platform::RUBY
  gem.author                = 'Manuel Meurer'
  gem.email                 = 'manuel@krautcomputing.com'
  gem.summary               = 'A nifty service layer for your Rails app'
  gem.description           = 'A nifty service layer for your Rails app'
  gem.homepage              = 'https://manuelmeurer.com/services/'
  gem.license               = 'MIT'
  gem.required_ruby_version = '>= 2.7'
  gem.files                 = files - test_files
  gem.executables           = gem.files.grep(%r(\Abin/)).map(&File.method(:basename))
  gem.test_files            = test_files
  gem.require_paths         = ['lib']

  gem.add_development_dependency 'rake',            '>= 0.9.0'
  gem.add_development_dependency 'guard-rspec',     '~> 4.2'
  gem.add_development_dependency 'rspec',           '~> 3.0'
  gem.add_development_dependency 'sidekiq',         '~> 5.0'
  gem.add_development_dependency 'redis',           '~> 3.0'
  gem.add_development_dependency 'redis-namespace', '~> 1.5'
  gem.add_development_dependency 'tries',           '~> 0.3'
  gem.add_development_dependency 'timecop',         '~> 0.7'
  gem.add_development_dependency 'sqlite3',         '~> 1.3'
  gem.add_development_dependency 'appraisal',       '~> 2.1'
  gem.add_runtime_dependency     'rails',           '>= 6.0'
  gem.add_runtime_dependency     'gem_config',      '~> 0.3'
end
