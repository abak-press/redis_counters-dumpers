# coding: utf-8
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

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
end
