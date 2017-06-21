require 'active_support/concern'
require_relative 'base'

module RedisCounters
  module Dumpers
    module Dsl
      # Модуль реализующий DSL для класса Engine::Base
      module Engine
        extend ActiveSupport::Concern

        class Configuration < ::RedisCounters::Dumpers::Dsl::Base
          alias_method :engine, :target

          setter :name
          setter :fields
          setter :temp_table_name

          callback_setter :on_before_merge
          callback_setter :on_prepare_row
          callback_setter :on_after_merge
          callback_setter :on_after_delete

          def destination(&block)
            engine.destinations << ::RedisCounters::Dumpers::Destination.build(engine, &block)
          end
        end

        module ClassMethods
          def build(&block)
            engine = new
            Configuration.new(engine, &block)
            engine
          end
        end
      end
    end
  end
end
