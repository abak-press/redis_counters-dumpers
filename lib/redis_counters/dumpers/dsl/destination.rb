require 'active_support/concern'
require_relative 'base'

module RedisCounters
  module Dumpers
    module Dsl
      # Модуль реализующий DSL для класса Destination
      module Destination
        extend ActiveSupport::Concern

        class Configuration < ::RedisCounters::Dumpers::Dsl::Base
          alias_method :destination, :target

          setter :model
          setter :matching_expr
          setter :value_delimiter

          varags_setter :fields
          varags_setter :key_fields
          varags_setter :increment_fields
          varags_setter :group_by

          alias_method :take, :fields

          def map(field, target_field)
            destination.fields_map.merge!(field.to_sym => target_field[:to])
          end

          def condition(value)
            destination.conditions << value
          end

          def source_condition(value)
            destination.source_conditions << value
          end
        end

        module ClassMethods
          def build(engine, &block)
            destination = new(engine)
            Configuration.new(destination, &block)
            destination
          end
        end
      end
    end
  end
end
