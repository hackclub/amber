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

ActiveRecord::Schema[8.1].define(version: 2026_09_23_014704) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "services", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_services_on_name", unique: true
  end

  create_table "tickets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "message", null: false
    t.integer "priority", default: 1, null: false
    t.bigint "service_id", null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.bigint "topic_id", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.bigint "user_id", null: false
    t.index ["priority"], name: "index_tickets_on_priority"
    t.index ["service_id"], name: "index_tickets_on_service_id"
    t.index ["status"], name: "index_tickets_on_status"
    t.index ["topic_id"], name: "index_tickets_on_topic_id"
    t.index ["user_id"], name: "index_tickets_on_user_id"
  end

  create_table "topics", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "service_id", null: false
    t.datetime "updated_at", null: false
    t.index ["service_id", "name"], name: "index_topics_on_service_id_and_name", unique: true
    t.index ["service_id"], name: "index_topics_on_service_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.boolean "priority_boost", default: false, null: false
    t.string "slack_id"
    t.string "sub", null: false
    t.datetime "updated_at", null: false
    t.index ["sub"], name: "index_users_on_sub", unique: true
  end

  add_foreign_key "tickets", "services"
  add_foreign_key "tickets", "topics"
  add_foreign_key "tickets", "users"
  add_foreign_key "topics", "services"
end
