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

ActiveRecord::Schema[8.1].define(version: 2026_09_26_000002) do
  create_table "comments", force: :cascade do |t|
    t.integer "reviewed_object_id", null: false
    t.string "ulid", null: false
    t.string "author_email", null: false
    t.string "author_name"
    t.text "body", null: false
    t.json "selector"
    t.datetime "commented_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reviewed_object_id"], name: "index_comments_on_reviewed_object_id"
    t.index ["ulid"], name: "index_comments_on_ulid", unique: true
  end

  create_table "reviewed_objects", force: :cascade do |t|
    t.string "bucket", null: false
    t.string "key", null: false
    t.string "etag"
    t.integer "size", limit: 8
    t.string "content_type"
    t.datetime "last_modified"
    t.string "status", default: "pending", null: false
    t.datetime "status_updated_at"
    t.string "reviewer"
    t.datetime "indexed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bucket", "key"], name: "index_reviewed_objects_on_bucket_and_key", unique: true
    t.index ["bucket", "status"], name: "index_reviewed_objects_on_bucket_and_status"
  end

  add_foreign_key "comments", "reviewed_objects"
end
