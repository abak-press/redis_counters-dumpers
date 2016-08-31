require 'spec_helper'

describe RedisCounters::Dumpers::Engine do
  let(:dumper) do
    RedisCounters::Dumpers::Engine.build do
      name :stats_totals
      fields record_id: :integer,
             column_id: :integer,
             value: :integer,
             date: :date,
             subject: [:enum, {name: :subject_types}],
             params: :hstore

      destination do
        model StatsByDay
        take :record_id, :column_id, :hits, :date, :params
        key_fields :record_id, :column_id, :date, :params
        increment_fields :hits
        map :hits, to: :value
        condition 'target.date = :date'
      end

      destination do
        model StatsTotal
        take :record_id, :column_id, :hits, :params
        key_fields :record_id, :column_id, :params
        increment_fields :hits
        map :hits, to: :value
      end

      destination do
        model StatsAggTotal
        take :record_id, :hits
        key_fields :record_id
        increment_fields :hits
        map :hits, to: 'sum(value)'
        group_by :record_id
      end

      on_before_merge do |dumper, _connection|
        dumper.common_params = {date: dumper.args[:date].strftime('%Y-%m-%d')}
      end
    end
  end

  let(:prev_date) { Date.new(2015, 1, 19) }
  let(:prev_date_s) { prev_date.strftime('%Y-%m-%d') }

  let(:date) { Date.new(2015, 1, 20) }
  let(:date_s) { date.strftime('%Y-%m-%d') }

  let(:counter) do
    RedisCounters.create_counter(Redis.current,
      counter_class: RedisCounters::HashCounter,
      counter_name: :record_hits_by_day,
      group_keys: [:record_id, :column_id, :subject, :params],
      partition_keys: [:date]
    )
  end

  before do
    allow(dumper).to receive(:redis_session).and_return(MockRedis.new)
  end

  describe '#process!' do
    before do
      counter.increment(date: prev_date_s, record_id: 1, column_id: 100, subject: '', params: '')
      counter.increment(date: prev_date_s, record_id: 1, column_id: 200, subject: '', params: '')
      counter.increment(date: prev_date_s, record_id: 1, column_id: 200, subject: '', params: '')
      counter.increment(date: prev_date_s, record_id: 2, column_id: 100, subject: nil, params: '')

      params = {a: 1}.stringify_keys.to_s[1..-2]
      counter.increment(date: prev_date_s, record_id: 3, column_id: 300, subject: nil, params: params)

      dumper.process!(counter, date: prev_date)

      counter.increment(date: date_s, record_id: 1, column_id: 100, subject: '', params: '')
      counter.increment(date: date_s, record_id: 1, column_id: 200, subject: '', params: '')
      counter.increment(date: date_s, record_id: 1, column_id: 200, subject: '', params: '')
      counter.increment(date: date_s, record_id: 2, column_id: 100, subject: nil, params: '')

      dumper.process!(counter, date: date)
    end

    Then { expect(StatsByDay.count).to eq 7 }
    And { expect(StatsByDay.where(record_id: 1, column_id: 100, date: prev_date).first.hits).to eq 1 }
    And { expect(StatsByDay.where(record_id: 1, column_id: 200, date: prev_date).first.hits).to eq 2 }
    And { expect(StatsByDay.where(record_id: 2, column_id: 100, date: prev_date).first.hits).to eq 1 }
    And { expect(StatsByDay.where(record_id: 3, column_id: 300, date: prev_date).first.params).to eq("a" => "1") }
    And { expect(StatsByDay.where(record_id: 1, column_id: 100, date: date).first.hits).to eq 1 }
    And { expect(StatsByDay.where(record_id: 1, column_id: 200, date: date).first.hits).to eq 2 }
    And { expect(StatsByDay.where(record_id: 2, column_id: 100, date: date).first.hits).to eq 1 }

    And { expect(StatsTotal.count).to eq 4 }
    And { expect(StatsTotal.where(record_id: 1, column_id: 100).first.hits).to eq 2 }
    And { expect(StatsTotal.where(record_id: 1, column_id: 200).first.hits).to eq 4 }
    And { expect(StatsTotal.where(record_id: 2, column_id: 100).first.hits).to eq 2 }

    And { expect(StatsAggTotal.count).to eq 3 }
    And { expect(StatsAggTotal.where(record_id: 1).first.hits).to eq 6 }
    And { expect(StatsAggTotal.where(record_id: 2).first.hits).to eq 2 }

    context 'with source conditions' do
      let(:dumper) do
        RedisCounters::Dumpers::Engine.build do
          name :stats_totals
          fields record_id: :integer,
                 column_id: :integer,
                 value: :integer,
                 date: :date

          destination do
            model StatsByDay
            take :record_id, :column_id, :hits, :date
            key_fields :record_id, :column_id, :date
            increment_fields :hits
            map :hits, to: :value
            condition 'target.date = :date'
            source_condition 'column_id = 100'
          end

          destination do
            model StatsTotal
            take :record_id, :column_id, :hits
            key_fields :record_id, :column_id
            increment_fields :hits
            map :hits, to: :value
            source_condition 'column_id = 100'
          end

          destination do
            model StatsAggTotal
            take :record_id, :hits
            key_fields :record_id
            increment_fields :hits
            map :hits, to: 'sum(value)'
            group_by :record_id
            source_condition 'column_id = 100'
          end

          on_before_merge do |dumper, _connection|
            dumper.common_params = {date: dumper.args[:date].strftime('%Y-%m-%d')}
          end
        end
      end

      Then { expect(StatsByDay.count).to eq 4 }
      And { expect(StatsByDay.where(record_id: 1, column_id: 100, date: prev_date).first.hits).to eq 1 }
      And { expect(StatsByDay.where(record_id: 2, column_id: 100, date: prev_date).first.hits).to eq 1 }
      And { expect(StatsByDay.where(record_id: 1, column_id: 100, date: date).first.hits).to eq 1 }
      And { expect(StatsByDay.where(record_id: 2, column_id: 100, date: date).first.hits).to eq 1 }

      And { expect(StatsTotal.count).to eq 2 }
      And { expect(StatsTotal.where(record_id: 1, column_id: 100).first.hits).to eq 2 }
      And { expect(StatsTotal.where(record_id: 2, column_id: 100).first.hits).to eq 2 }

      And { expect(StatsAggTotal.count).to eq 2 }
      And { expect(StatsAggTotal.where(record_id: 1).first.hits).to eq 2 }
      And { expect(StatsAggTotal.where(record_id: 2).first.hits).to eq 2 }
    end
  end
end
