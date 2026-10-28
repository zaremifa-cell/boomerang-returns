class CreateCoreTables < ActiveRecord::Migration[8.1]
  def change
    create_table :retailers do |t|
      t.string :name, null: false
      t.string :slug, null: false, index: { unique: true }
      t.string :api_token, null: false, index: { unique: true }
      t.integer :return_window_days, null: false, default: 30
      t.string :allowed_countries, array: true, null: false, default: []
      t.timestamps
    end

    create_table :orders do |t|
      t.references :retailer, null: false, foreign_key: true
      t.string :number, null: false
      t.string :email, null: false
      t.string :country, null: false
      t.datetime :delivered_at
      t.timestamps
      t.index [:retailer_id, :number], unique: true
    end

    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.string :sku, null: false
      t.string :name, null: false
      t.integer :price_cents, null: false
      t.integer :quantity, null: false, default: 1
      t.boolean :final_sale, null: false, default: false
      t.timestamps
    end

    create_table :return_requests do |t|
      t.references :order, null: false, foreign_key: true
      t.string :public_id, null: false, index: { unique: true }
      t.string :idempotency_key, null: false
      t.string :status, null: false, default: "label_pending"
      t.string :carrier, null: false
      t.string :tracking_number
      t.string :label_url
      t.integer :label_attempts, null: false, default: 0
      t.string :last_error
      t.timestamps
      t.index [:order_id, :idempotency_key], unique: true
      t.index :status
    end

    create_table :return_items do |t|
      t.references :return_request, null: false, foreign_key: true
      t.references :order_item, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.string :reason, null: false
      t.timestamps
    end

    create_table :tracking_events do |t|
      t.references :return_request, null: false, foreign_key: true
      t.string :external_id, null: false, index: { unique: true }
      t.string :status, null: false
      t.datetime :occurred_at, null: false
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end
  end
end
