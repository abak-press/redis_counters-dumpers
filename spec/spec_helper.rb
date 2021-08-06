require 'redis_counters/dumpers'

require 'combustion'
Combustion.initialize! :active_record

require 'rspec/rails'
require 'pry-byebug'

require 'redis'
Redis.current = Redis.new(host: ENV['TEST_REDIS_HOST'])

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.before { Redis.current.flushdb }
end
