# coding: utf-8
require 'forwardable'
require 'active_support/core_ext/hash/indifferent_access'
require_relative 'dsl/destination'

module RedisCounters
  module Dumpers
    # Класс представляет конечную точку сохранения данных счетчика.
    #
    # Описывает в какую модель (таблицу), какие поля имеющиеся в распоряжении дампера,
    # должны быть сохранены и каким образом.
    #
    # По сути, мерджит указанные поля из temp - таблицы, дампера
    # в указанную таблицу.
    #
    # Может использоваться как напрямую так и с помощью DSL (см. модуль RedisCounters::Dumpers::Dsl::Destination).
    class Destination
      extend Forwardable
      include ::RedisCounters::Dumpers::Dsl::Destination

      # Ссылка на родительский движек - дампер.
      attr_accessor :engine

      # Модель, в таблицу, которой будет производится мердж данных, AR::Model.
      attr_accessor :model

      # Список полей, из доступных дамперу, которые необходимо сохранить, Array.
      attr_accessor :fields

      # Список полей, по комбинации которых, будет происходить определение существования записи,
      # при мердже данных, Array.
      attr_accessor :key_fields

      # Список полей, которые будет инкрементированы при обновлении существующей записи, Array.
      attr_accessor :increment_fields

      # Карта полей - карта псевдонимов полей, Hash.
      # Названия полей в целевой таблице, могут отличаться от названий полей дампера.
      # Для сопоставления полей целевой таблицы и дампера, необходимо заполнить карту соответствия.
      # Карта, заполняется только для тех полей, названия которых отличаются.
      # Во всех свойствах, содержащий указания полей: fields, key_fields, increment_fields, conditions
      # используются имена конечных полей целевой таблицы.
      #
      # Example:
      #   fields_map = {:pages => :value, :date => :start_month_date}
      #
      # Означает, что целевое поле :pages, указывает на поле :value, дампера,
      # а целевое поле :date, указывает на поле :start_month_date, дампера.
      attr_accessor :fields_map

      # Список дополнительных условий, которые применяются при обновлении целевой таблицы, Array of String.
      # Каждое условие представляет собой строку - часть SQL выражения, которое может включать именованные
      # параметры из числа доступных в хеше оббщих параметров дампера: engine.common_params.
      # Условия соеденяются через AND.
      attr_accessor :conditions

      def initialize(engine)
        @engine = engine
        @fields_map = HashWithIndifferentAccess.new
        @conditions = []
      end

      def merge
        target_fields = fields.join(', ')

        sql = <<-SQL
          WITH
            source AS
            (
              SELECT #{selected_fields_expression}
                FROM #{source_table}
            ),
            updated AS
            (
              UPDATE #{target_table} target
              SET
                #{updating_expression}
              FROM source
              WHERE #{matching_expression}
                #{extra_conditions}
              RETURNING target.*
            )
          INSERT INTO #{target_table} (#{target_fields})
            SELECT #{target_fields}
            FROM source
          WHERE NOT EXISTS (
            SELECT 1
              FROM updated target
            WHERE #{matching_expression}
              #{extra_conditions}
          )
        SQL

        sql = model.send(:sanitize_sql, [sql, engine.common_params])
        connection.execute sql
      end

      def_delegator :model, :connection
      def_delegator :model, :quoted_table_name, :target_table
      def_delegator :engine, :temp_table_name, :source_table

      protected

      def selected_fields_expression
        full_fields_map.map { |target_field, source_field| "#{source_field} as #{target_field}" }.join(', ')
      end

      def full_fields_map
        fields_map.reverse_merge(Hash[fields.zip(fields)])
      end

      def updating_expression
        increment_fields.map { |field| "#{field} = COALESCE(target.#{field}, 0) + source.#{field}" }.join(', ')
      end

      def matching_expression
        source_key_fields = key_fields.map { |field| "source.#{field}" }.join(', ')
        target_key_fields = key_fields.map { |field| "target.#{field}" }.join(', ')
        "(#{source_key_fields}) = (#{target_key_fields})"
      end

      def extra_conditions
        result = conditions.map { |condition| "(#{condition})" }.join(' AND ')
        result.present? ? "AND #{result}" : result
      end
    end
  end
end
