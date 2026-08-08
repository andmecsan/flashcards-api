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

ActiveRecord::Schema[8.1].define(version: 2026_08_08_164733) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "card_reviews", force: :cascade do |t|
    t.bigint "card_id", null: false
    t.datetime "created_at", null: false
    t.float "easiness", default: 2.5, null: false
    t.integer "interval", default: 1, null: false
    t.datetime "next_review_at", null: false
    t.integer "repetitions", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["card_id", "user_id"], name: "index_card_reviews_on_card_id_and_user_id", unique: true
    t.index ["card_id"], name: "index_card_reviews_on_card_id"
    t.index ["next_review_at"], name: "index_card_reviews_on_next_review_at"
    t.index ["user_id"], name: "index_card_reviews_on_user_id"
  end

  create_table "cards", force: :cascade do |t|
    t.text "back", null: false
    t.datetime "created_at", null: false
    t.bigint "deck_id", null: false
    t.text "front", null: false
    t.datetime "updated_at", null: false
    t.index ["deck_id"], name: "index_cards_on_deck_id"
  end

  create_table "decks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "name"], name: "index_decks_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_decks_on_user_id"
  end

  create_table "review_logs", force: :cascade do |t|
    t.bigint "card_review_id", null: false
    t.integer "quality", null: false
    t.datetime "reviewed_at", null: false
    t.index ["card_review_id"], name: "index_review_logs_on_card_review_id"
    t.index ["reviewed_at"], name: "index_review_logs_on_reviewed_at"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["uid"], name: "index_users_on_uid", unique: true
  end

  add_foreign_key "card_reviews", "cards"
  add_foreign_key "card_reviews", "users"
  add_foreign_key "cards", "decks"
  add_foreign_key "decks", "users"
  add_foreign_key "review_logs", "card_reviews"
end
