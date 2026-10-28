# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_28_080000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.string "sku", null: false
    t.string "name", null: false
    t.integer "price_cents", null: false
    t.integer "quantity", default: 1, null: false
    t.boolean "final_sale", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "retailer_id", null: false
    t.string "number", null: false
    t.string "email", null: false
    t.string "country", null: false
    t.datetime "delivered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["retailer_id", "number"], name: "index_orders_on_retailer_id_and_number", unique: true
    t.index ["retailer_id"], name: "index_orders_on_retailer_id"
  end

  create_table "retailers", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "api_token", null: false
    t.integer "return_window_days", default: 30, null: false
    t.string "allowed_countries", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_token"], name: "index_retailers_on_api_token", unique: true
    t.index ["slug"], name: "index_retailers_on_slug", unique: true
  end

  create_table "return_items", force: :cascade do |t|
    t.bigint "return_request_id", null: false
    t.bigint "order_item_id", null: false
    t.integer "quantity", null: false
    t.string "reason", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_item_id"], name: "index_return_items_on_order_item_id"
    t.index ["return_request_id"], name: "index_return_items_on_return_request_id"
  end

  create_table "return_requests", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.string "public_id", null: false
    t.string "idempotency_key", null: false
    t.string "status", default: "label_pending", null: false
    t.string "carrier", null: false
    t.string "tracking_number"
    t.string "label_url"
    t.integer "label_attempts", default: 0, null: false
    t.string "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "idempotency_key"], name: "index_return_requests_on_order_id_and_idempotency_key", unique: true
    t.index ["order_id"], name: "index_return_requests_on_order_id"
    t.index ["public_id"], name: "index_return_requests_on_public_id", unique: true
    t.index ["status"], name: "index_return_requests_on_status"
  end

  create_table "tracking_events", force: :cascade do |t|
    t.bigint "return_request_id", null: false
    t.string "external_id", null: false
    t.string "status", null: false
    t.datetime "occurred_at", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_tracking_events_on_external_id", unique: true
    t.index ["return_request_id"], name: "index_tracking_events_on_return_request_id"
  end

  add_foreign_key "order_items", "orders"
  add_foreign_key "orders", "retailers"
  add_foreign_key "return_items", "order_items"
  add_foreign_key "return_items", "return_requests"
  add_foreign_key "return_requests", "orders"
  add_foreign_key "tracking_events", "return_requests"
end
