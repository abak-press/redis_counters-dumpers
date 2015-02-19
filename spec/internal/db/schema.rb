ActiveRecord::Schema.define do
  create_table :stats_by_days do |t|
    t.integer :record_id, null: false
    t.integer :column_id, null: false
    t.date :date, null: false
    t.integer :hits, null: false, default: 0
  end

  add_index :stats_by_days, [:record_id, :column_id, :date], unique: true

  create_table :stats_totals do |t|
    t.integer :record_id, null: false
    t.integer :column_id, null: false
    t.integer :hits, null: false, default: 0
  end

  add_index :stats_totals, [:record_id, :column_id], unique: true

  create_table :stats_agg_totals do |t|
    t.integer :record_id, null: false
    t.integer :hits, null: false, default: 0
  end

  add_index :stats_agg_totals, [:record_id], unique: true
end
