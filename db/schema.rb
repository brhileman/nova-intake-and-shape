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

ActiveRecord::Schema[8.1].define(version: 2026_01_28_160000) do
  create_schema "extensions"

  # These are extensions that must be enabled in order to support this database
  enable_extension "extensions.pg_stat_statements"
  enable_extension "extensions.pgcrypto"
  enable_extension "extensions.uuid-ossp"
  enable_extension "graphql.pg_graphql"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vault.supabase_vault"

  create_table "public.briefs", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.bigint "request_id", null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1
    t.index ["request_id"], name: "index_briefs_on_request_id"
  end

  create_table "public.comments", force: :cascade do |t|
    t.string "author_name"
    t.string "author_type"
    t.text "content"
    t.datetime "created_at", null: false
    t.string "phase"
    t.bigint "request_id", null: false
    t.datetime "updated_at", null: false
    t.index ["request_id"], name: "index_comments_on_request_id"
  end

  create_table "public.executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "pr_url"
    t.string "preview_url"
    t.bigint "request_id", null: false
    t.text "summary"
    t.datetime "updated_at", null: false
    t.index ["request_id"], name: "index_executions_on_request_id"
  end

  create_table "public.plans", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.bigint "request_id", null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1
    t.index ["request_id"], name: "index_plans_on_request_id"
  end

  create_table "public.projects", force: :cascade do |t|
    t.text "context_docs"
    t.datetime "created_at", null: false
    t.string "default_branch", default: "main"
    t.boolean "environment_configured", default: false
    t.string "name", null: false
    t.string "repo_url", null: false
    t.datetime "updated_at", null: false
  end

  create_table "public.requests", force: :cascade do |t|
    t.text "bug_summary"
    t.datetime "created_at", null: false
    t.string "current_agent_id"
    t.decimal "estimate_days"
    t.string "generated_title"
    t.text "original_input", null: false
    t.bigint "project_id", null: false
    t.integer "request_number"
    t.integer "request_type", default: 0
    t.boolean "requires_design_input", default: false
    t.string "status", default: "intake_pending"
    t.datetime "updated_at", null: false
    t.text "user_story_action"
    t.text "user_story_outcome"
    t.string "user_story_persona"
    t.index ["project_id", "request_number"], name: "index_requests_on_project_id_and_request_number", unique: true
    t.index ["project_id"], name: "index_requests_on_project_id"
    t.index ["request_type"], name: "index_requests_on_request_type"
    t.index ["status"], name: "index_requests_on_status"
  end

  add_foreign_key "public.briefs", "public.requests"
  add_foreign_key "public.comments", "public.requests"
  add_foreign_key "public.executions", "public.requests"
  add_foreign_key "public.plans", "public.requests"
  add_foreign_key "public.requests", "public.projects"

end
