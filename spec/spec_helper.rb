# coding: utf-8
require 'bundler/setup'
require 'redis_counters/dumpers'

if ::ActiveRecord::VERSION::MAJOR < 4
  require 'activerecord-postgres-hstore'
  require 'simple_hstore_accessor'
end

require 'combustion'
Combustion.initialize! :active_record

require 'rspec/rails'
require 'rspec/given'

require 'mock_redis'
require 'redis'
Redis.current = MockRedis.new

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.before { Redis.current.flushdb }
end
