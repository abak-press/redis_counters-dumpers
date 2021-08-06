lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'redis_counters/dumpers/version'

Gem::Specification.new do |spec|
  spec.name          = 'redis_counters-dumpers'
  spec.version       = RedisCounters::Dumpers::VERSION
  spec.authors       = ['Merkushin']
  spec.email         = ['bibendi@bk.ru']
  spec.summary       = 'Dump statistics from Redis to DB'
  spec.homepage      = 'https://github.com/abak-press/redis_counters-dumpers'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activesupport', '>= 3.0', '< 5'
  spec.add_runtime_dependency 'activerecord', '>= 3.0'
  spec.add_runtime_dependency 'redis', '>= 3.0'
  spec.add_runtime_dependency 'redis-namespace', '>= 1.3'
  spec.add_runtime_dependency 'callbacks_rb', '>= 0.0.1'
  spec.add_runtime_dependency 'redis_counters', '>= 1.3'

  spec.add_development_dependency 'bundler', '>= 1.7'
  spec.add_development_dependency 'rake', '>= 10.0'
  spec.add_development_dependency 'rspec', '>= 3.2'
  spec.add_development_dependency 'rspec-rails', '~> 3.9.1'
  spec.add_development_dependency 'appraisal', '>= 1.0.2'
  spec.add_development_dependency 'mock_redis'
  spec.add_development_dependency 'combustion'
  spec.add_development_dependency 'pry-byebug'
end
