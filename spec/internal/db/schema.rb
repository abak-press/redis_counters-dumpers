ActiveRecord::Schema.define do
  execute <<-SQL
    CREATE TYPE subject_types AS ENUM ('');
  SQL

  if ::ActiveRecord::VERSION::MAJOR < 4
    execute <<-SQL
      CREATE EXTENSION IF NOT EXISTS hstore;
    SQL
  else
    enable_extension :hstore
  end

  create_table :stats_by_days do |t|
    t.integer :record_id, null: false
    t.integer :column_id, null: false
    t.date :date, null: false
    t.integer :hits, null: false, default: 0
    t.column :subject, :subject_types
    t.hstore :params
  end

  add_index :stats_by_days, [:record_id, :column_id, :date], unique: true

  create_table :stats_totals do |t|
    t.integer :record_id, null: false
    t.integer :column_id, null: false
    t.integer :hits, null: false, default: 0
    t.column :subject, :subject_types
    t.hstore :params
  end

  add_index :stats_totals, [:record_id, :column_id], unique: true

  create_table :stats_agg_totals do |t|
    t.integer :record_id, null: false
    t.integer :hits, null: false, default: 0
    t.column :subject, :subject_types
  end

  add_index :stats_agg_totals, [:record_id], unique: true
end
