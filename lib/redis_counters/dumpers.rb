require 'redis_counters/dumpers/version'

module RedisCounters
  module Dumpers
    autoload :Engine, 'redis_counters/dumpers/engine'
    autoload :Destination, 'redis_counters/dumpers/destination'
    autoload :List, 'redis_counters/dumpers/list'
  end
end
