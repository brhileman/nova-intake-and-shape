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

ActiveRecord::Schema[8.0].define(version: 2026_01_28_071746) do
  create_schema "auth"
  create_schema "extensions"
  create_schema "graphql"
  create_schema "graphql_public"
  create_schema "pgbouncer"
  create_schema "realtime"
  create_schema "storage"
  create_schema "vault"

  # These are extensions that must be enabled in order to support this database
  enable_extension "extensions.pg_stat_statements"
  enable_extension "extensions.pgcrypto"
  enable_extension "extensions.uuid-ossp"
  enable_extension "graphql.pg_graphql"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vault.supabase_vault"

  create_table "briefs", force: :cascade do |t|
    t.bigint "request_id", null: false
    t.integer "version", default: 1
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["request_id"], name: "index_briefs_on_request_id"
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "request_id", null: false
    t.string "author_type"
    t.string "author_name"
    t.text "content"
    t.string "phase"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["request_id"], name: "index_comments_on_request_id"
  end

  create_table "executions", force: :cascade do |t|
    t.bigint "request_id", null: false
    t.string "pr_url"
    t.string "preview_url"
    t.text "summary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["request_id"], name: "index_executions_on_request_id"
  end

  create_table "plans", force: :cascade do |t|
    t.bigint "request_id", null: false
    t.integer "version", default: 1
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["request_id"], name: "index_plans_on_request_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.string "repo_url", null: false
    t.string "default_branch", default: "main"
    t.text "context_docs"
    t.boolean "environment_configured", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "requests", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.text "original_input", null: false
    t.string "status", default: "intake_pending"
    t.boolean "requires_design_input", default: false
    t.string "current_agent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "request_type", default: 0
    t.string "generated_title"
    t.string "user_story_persona"
    t.text "user_story_action"
    t.text "user_story_outcome"
    t.text "bug_summary"
    t.decimal "estimate_days"
    t.index ["project_id"], name: "index_requests_on_project_id"
    t.index ["request_type"], name: "index_requests_on_request_type"
    t.index ["status"], name: "index_requests_on_status"
  end

  add_foreign_key "briefs", "requests"
  add_foreign_key "comments", "requests"
  add_foreign_key "executions", "requests"
  add_foreign_key "plans", "requests"
  add_foreign_key "requests", "projects"
end
