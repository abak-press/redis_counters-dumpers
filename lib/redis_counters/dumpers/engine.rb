# coding: utf-8
require 'forwardable'
require 'callbacks_rb'
require 'active_support/core_ext/hash/indifferent_access'
require 'redis'
require 'redis/namespace'
require 'redis_counters'
require_relative 'dsl/engine'

module RedisCounters
  module Dumpers
    # Класс дампер (движек дампера) - класс осуществляющий перенос данных счетчика в БД.
    #
    # Может использоваться как напрямую так и с помощью DSL (см. модуль RedisCounters::Dumpers::Dsl::Engine).
    #
    # Общий алгоритм работы:
    #   - копируем данные счетчика в временную таблицу
    #   - мерджим данные во все целевые таблицы
    #   - удаляем перенесенные данные из счетчика
    #
    # Все destinations должны быть в рамках одной БД.
    # Все действия происходят в рамках соединения БД, первой destination.
    #
    # Example:
    #   dumper = Dumper.build do
    #     name :hits_by_day
    #
    #     fields => {
    #       :company_id => :integer,
    #       :value => :integer,
    #       :date => :date,
    #       :start_month_date => :date,
    #     }
    #
    #     destination do
    #       model            CompanyStatisticTotalByDay
    #       take             :company_id, :pages, :date
    #       key_fields       :company_id, :date
    #       increment_fields :pages
    #       map              :pages, :to => :value
    #       condition        'target.date = :date'
    #     end
    #
    #     destination do
    #       model            CompanyStatisticTotalByMonth
    #       take             :company_id, :pages, :date
    #       key_fields       :company_id, :date
    #       increment_fields :pages
    #       map              :pages, :to => :value
    #       map              :date,  :to => :start_month_date
    #       condition        'target.date = :start_month_date'
    #     end
    #
    #     on_before_merge do |dumper, connection|
    #       dumper.common_params = {
    #         :date             => dumper.date.strftime('%Y-%m-%d'),
    #         :start_month_date => dumper.date.beginning_of_month.strftime('%Y-%m-%d'),
    #       }
    #     end
    #   end
    #
    #   dumper.process!(counter, date: Date.yesterday)
    #
    # В результате все данные счетчика за вчера, будут
    # смерджены в целевые таблицы, по ключевым полям: company_id и date,
    # причем все поля кроме pages, будут просто записаны в таблицы,
    # а поле pages будет инкрементировано с текущим значением, при обновлении.
    # Данные будут удалены из счетчика.
    # Все действия производятся транзакционно, как в БД, так и в Redis.
    class Engine
      include CallbacksRb
      include ::RedisCounters::Dumpers::Dsl::Engine
      extend Forwardable

      DATE_FORMAT = '%Y-%m-%d'.freeze

      # properties/accessors

      # Название дампера
      attr_reader :name

      # Список доступных для сохранение в целевые таблицы полей и их типов данных, в виде Hash.
      # Доступны следующие типы данных: string, integer, date, timestamp, boolean.
      # Преобразование типов производится непосредственно перед мерджем в целевые таблицы.
      #
      # Example:
      #  fields = {:company_id => :integer, :date => :timestamp}
      attr_reader :fields

      # Массив, целевых моделей для сохранение данных, Array.
      # Каждый элемент массива это экземпляр класса Engine::Destination.
      attr_accessor :destinations

      # Название temp таблицы, используемой для переноса данных.
      # По умолчанию: "tmp_#{dumper_name}"
      attr_accessor :temp_table_name

      # Хеш общий параметров.
      # Данные хеш мерджится в каждую, поступающую от счетчика, строку данных.
      attr_accessor :common_params

      attr_reader :counter
      attr_reader :args

      # callbacks

      # Вызывается, перед процессом мерджа данных, в рамках БД - транзакции.
      # Параметры: dumper, db_connection.
      callback :on_before_merge

      # Вызывается для каждой строки, полученной от счетчика.
      # Позволяет вычисляить дополнительные данные, которые необходимы для сохранения,
      # или произвести предварительную обработку данных от счетчика перед сохранением.
      # В in/out параметре row передается строка данных от счетчика, в виде хеша.
      # Так же, row содержит все общие данные, заданные для дампера в свойстве common_params.
      # Параметры: dumper, row.
      callback :on_prepare_row

      # Вызывается, по окончанию процесса мерджа данных, в рамках БД - транзакции.
      # Параметры: dumper, db_connection.
      callback :on_after_merge

      # Вызывается, по окончанию процесса удаления данных из счетчика, в рамках redis - транзакции.
      # Параметры: dumper, redis_connection.
      callback :on_after_delete

      # Public: Производит перенос данных счетчика.
      #
      # counter - экземпляр счетчика.
      # args    - Hash - набор аргументов(кластер и/или партиции) для переноса данных.
      #
      # Returns Fixnum - кол-во обработанных строк.
      #
      def process!(counter, args = {})
        @counter = counter
        @args = args

        db_transaction do
          merge_data
          start_redis_transaction
          delete_from_redis
        end

        commit_redis_transaction

        rows_processed
      end

      def initialize
        @destinations = []
        @common_params  = {}
      end

      def fields=(value)
        @fields = value.with_indifferent_access
      end

      def name=(value)
        @name = value
        @temp_table_name = "tmp_#{@name}"
      end

      protected

      attr_accessor :rows_processed

      def_delegator :redis_session, :multi, :start_redis_transaction
      def_delegator :redis_session, :exec, :commit_redis_transaction
      def_delegator :db_connection, :transaction, :db_transaction
      def_delegator :db_connection, :quote

      def merge_data
        fire_callback(:on_before_merge, self, db_connection)

        # копируем данные счетчика в временную таблицу
        create_temp_table
        fill_temp_table
        analyze_table

        # мерджим в целевые таблицы
        destinations.each { |dest| dest.merge }

        fire_callback(:on_after_merge, self, db_connection)

        drop_temp_table
      end

      def fill_temp_table
        @rows_processed = counter.data(args) do |batch|
          @current_batch = batch
          prepare_batch
          insert_batch
        end
      end

      def prepare_batch
        fields_keys = fields.keys

        @current_batch.map! do |row|
          row.merge!(common_params)
          fire_callback(:on_prepare_row, self, row)

          # выбираем из хеша только указанные поля
          fields_keys.inject(HashWithIndifferentAccess.new) do |result, (field)|
            result.merge!(field => row.fetch(field))
          end
        end
      end

      def insert_batch
        db_connection.execute <<-SQL
          INSERT INTO #{temp_table_name} VALUES #{batch_data}
        SQL
      end

      def batch_data
        @current_batch.map! do |row|
          values = row.map do |field, value|
            next 'null' if value.nil?
            fields.fetch(field).eql?(:integer) ? value : quote(value)
          end

          "(#{values.join(',')})"
        end.join(',')
      end

      def delete_from_redis
        redis_session.pipelined do |redis|
          counter.partitions(args).each do |partition|
            counter.delete_partition_direct!(args.merge(partition), redis)
          end
        end

        fire_callback(:on_after_delete, self, redis_session)
      end

      def redis_session
        @redis_session ||= begin
          redis = ::Redis.new(counter.redis.client.options)
          ::Redis::Namespace.new(counter.redis.namespace, :redis => redis)
        end
      end

      def create_temp_table
        db_connection.execute <<-SQL
          CREATE TEMP TABLE #{temp_table_name} (
            #{columns_definition}
          ) ON COMMIT DROP
        SQL
      end

      def drop_temp_table
        db_connection.execute "DROP TABLE #{temp_table_name}"
      end

      def analyze_table
        db_connection.execute <<-SQL
          ANALYZE #{temp_table_name}
        SQL
      end

      def columns_definition
        @fields.map do |field, type|
          pg_field_type = case type
                          when :string, :text
                            'character varying(4000)'
                          when :integer, :serial, :number
                            'integer'
                          when :date, :timestamp, :boolean, :hstore
                            type.to_s
                          else
                            if type.is_a?(Array) && type.first == :enum
                              type.last.fetch(:name)
                            else
                              raise 'Unknown datatype %s for %s field' % [type, field]
                            end
                          end

          "#{field} #{pg_field_type}"
        end.join(',')
      end

      def db_connection
        destinations.first.connection
      end
    end
  end
end
