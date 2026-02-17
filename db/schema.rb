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

ActiveRecord::Schema[8.1].define(version: 2026_02_12_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "comments", force: :cascade do |t|
    t.string "author_name"
    t.string "author_type"
    t.string "comment_type", default: "agent_chat", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.string "phase"
    t.bigint "request_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["comment_type"], name: "index_comments_on_comment_type"
    t.index ["request_id"], name: "index_comments_on_request_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "asana_project_gid"
    t.string "asana_workspace_gid"
    t.text "context_docs"
    t.datetime "created_at", null: false
    t.string "default_branch", default: "main"
    t.string "name", null: false
    t.bigint "pm_id"
    t.string "repo_url", null: false
    t.datetime "updated_at", null: false
    t.index ["pm_id"], name: "index_projects_on_pm_id"
  end

  create_table "requests", force: :cascade do |t|
    t.string "asana_task_gid"
    t.string "asana_task_url"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.decimal "estimate_days"
    t.string "generated_title"
    t.string "intake_agent_id"
    t.text "original_input", null: false
    t.text "plan_content"
    t.bigint "project_id", null: false
    t.integer "request_number"
    t.integer "request_type", default: 0
    t.string "status", default: "draft"
    t.text "summary"
    t.datetime "updated_at", null: false
    t.text "user_story_action"
    t.text "user_story_outcome"
    t.string "user_story_persona"
    t.index ["asana_task_gid"], name: "index_requests_on_asana_task_gid", unique: true, where: "(asana_task_gid IS NOT NULL)"
    t.index ["created_by_id"], name: "index_requests_on_created_by_id"
    t.index ["project_id", "request_number"], name: "index_requests_on_project_id_and_request_number", unique: true
    t.index ["project_id"], name: "index_requests_on_project_id"
    t.index ["request_type"], name: "index_requests_on_request_type"
    t.index ["status"], name: "index_requests_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "comments", "requests"
  add_foreign_key "comments", "users"
  add_foreign_key "projects", "users", column: "pm_id"
  add_foreign_key "requests", "projects"
  add_foreign_key "requests", "users", column: "created_by_id"
end
