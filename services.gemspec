# encoding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'services/version'

Gem::Specification.new do |gem|
  gem.name          = 'services'
  gem.version       = Services::VERSION
  gem.platform      = Gem::Platform::RUBY
  gem.author        = 'Manuel Meurer'
  gem.email         = 'manuel@krautcomputing.com'
  gem.summary       = ''
  gem.description   = ''
  gem.homepage      = 'http://krautcomputing.github.io/services'
  gem.license       = 'MIT'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r(^bin/)).map { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r(^(test|spec|features)/))
  gem.require_paths = ['lib']

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'guard-rspec', '~> 4.2'
  gem.add_development_dependency 'rspec', '~> 3.0'
  gem.add_development_dependency 'sidekiq', '~> 3.0'
  gem.add_development_dependency 'redis', '~> 3.0'
  gem.add_runtime_dependency 'rails', '>= 3.0.0'
  gem.add_runtime_dependency 'gem_config', '~> 0.3'
  gem.add_runtime_dependency 'nesty', '~> 1.0.2'
end
