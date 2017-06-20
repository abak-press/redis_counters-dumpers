require 'active_support/concern'
require 'redis_counters/dumpers/engine'

module RedisCounters
  module Dumpers
    module Dsl
      module List
        extend ActiveSupport::Concern

        module ClassMethods
          def build(&block)
            instance = new
            instance.instance_eval(&block)
            instance
          end
        end

        def dumper(id, &block)
          engine = ::RedisCounters::Dumpers::Engine.build(&block)
          engine.name = id
          @dumpers[id] = engine
        end
      end
    end
  end
end
