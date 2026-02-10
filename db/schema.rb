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

ActiveRecord::Schema[8.1].define(version: 2026_02_09_000001) do
  create_schema "extensions"

  # These are extensions that must be enabled in order to support this database
  enable_extension "extensions.pg_stat_statements"
  enable_extension "extensions.pgcrypto"
  enable_extension "extensions.uuid-ossp"
  enable_extension "graphql.pg_graphql"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vault.supabase_vault"

  create_table "public.active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "public.active_storage_blobs", force: :cascade do |t|
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

  create_table "public.active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "public.approvals", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "phase", null: false
    t.bigint "request_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["phase"], name: "index_approvals_on_phase"
    t.index ["request_id", "user_id", "phase"], name: "index_approvals_uniqueness", unique: true
    t.index ["request_id"], name: "index_approvals_on_request_id"
    t.index ["user_id"], name: "index_approvals_on_user_id"
  end

  create_table "public.comments", force: :cascade do |t|
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

  create_table "public.decomposition_plans", force: :cascade do |t|
    t.string "agent_id"
    t.integer "agent_message_count_at_followup"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.text "original_input", null: false
    t.text "plan_content"
    t.bigint "project_id", null: false
    t.string "status", default: "planning"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_decomposition_plans_on_agent_id"
    t.index ["created_by_id"], name: "index_decomposition_plans_on_created_by_id"
    t.index ["project_id"], name: "index_decomposition_plans_on_project_id"
    t.index ["status"], name: "index_decomposition_plans_on_status"
  end

  create_table "public.design_guidances", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "figma_url"
    t.datetime "provided_at"
    t.string "provided_by"
    t.bigint "request_id", null: false
    t.text "specifications"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["request_id"], name: "index_design_guidances_on_request_id"
    t.index ["user_id"], name: "index_design_guidances_on_user_id"
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
    t.bigint "created_by_id"
    t.bigint "request_id", null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1
    t.index ["created_by_id"], name: "index_plans_on_created_by_id"
    t.index ["request_id"], name: "index_plans_on_request_id"
  end

  create_table "public.projects", force: :cascade do |t|
    t.text "context_docs"
    t.datetime "created_at", null: false
    t.string "default_branch", default: "main"
    t.bigint "designer_id"
    t.bigint "dev_id"
    t.boolean "environment_configured", default: false
    t.string "name", null: false
    t.bigint "pm_id"
    t.string "repo_url", null: false
    t.datetime "updated_at", null: false
    t.index ["designer_id"], name: "index_projects_on_designer_id"
    t.index ["dev_id"], name: "index_projects_on_dev_id"
    t.index ["pm_id"], name: "index_projects_on_pm_id"
  end

  create_table "public.request_groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.bigint "decomposition_plan_id"
    t.text "description"
    t.string "name", null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_request_groups_on_created_by_id"
    t.index ["decomposition_plan_id"], name: "index_request_groups_on_decomposition_plan_id"
    t.index ["project_id", "name"], name: "index_request_groups_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_request_groups_on_project_id"
  end

  create_table "public.requests", force: :cascade do |t|
    t.integer "agent_message_count_at_followup"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "current_agent_id"
    t.text "dependencies"
    t.decimal "estimate_days"
    t.string "generated_title"
    t.text "original_input", null: false
    t.integer "position"
    t.integer "priority"
    t.bigint "project_id", null: false
    t.bigint "request_group_id"
    t.integer "request_number"
    t.integer "request_type", default: 0
    t.boolean "requires_design_input", default: false
    t.string "status", default: "intake_pending"
    t.text "summary"
    t.datetime "updated_at", null: false
    t.text "user_story_action"
    t.text "user_story_outcome"
    t.string "user_story_persona"
    t.index ["created_by_id"], name: "index_requests_on_created_by_id"
    t.index ["project_id", "position"], name: "index_requests_on_project_id_and_position"
    t.index ["project_id", "request_number"], name: "index_requests_on_project_id_and_request_number", unique: true
    t.index ["project_id"], name: "index_requests_on_project_id"
    t.index ["request_group_id"], name: "index_requests_on_request_group_id"
    t.index ["request_type"], name: "index_requests_on_request_type"
    t.index ["status"], name: "index_requests_on_status"
  end

  create_table "public.users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "public.active_storage_attachments", "public.active_storage_blobs", column: "blob_id"
  add_foreign_key "public.active_storage_variant_records", "public.active_storage_blobs", column: "blob_id"
  add_foreign_key "public.approvals", "public.requests"
  add_foreign_key "public.approvals", "public.users"
  add_foreign_key "public.comments", "public.requests"
  add_foreign_key "public.comments", "public.users"
  add_foreign_key "public.decomposition_plans", "public.projects"
  add_foreign_key "public.decomposition_plans", "public.users", column: "created_by_id"
  add_foreign_key "public.design_guidances", "public.requests"
  add_foreign_key "public.design_guidances", "public.users"
  add_foreign_key "public.executions", "public.requests"
  add_foreign_key "public.plans", "public.requests"
  add_foreign_key "public.plans", "public.users", column: "created_by_id"
  add_foreign_key "public.projects", "public.users", column: "designer_id"
  add_foreign_key "public.projects", "public.users", column: "dev_id"
  add_foreign_key "public.projects", "public.users", column: "pm_id"
  add_foreign_key "public.request_groups", "public.decomposition_plans"
  add_foreign_key "public.request_groups", "public.projects"
  add_foreign_key "public.request_groups", "public.users", column: "created_by_id"
  add_foreign_key "public.requests", "public.projects"
  add_foreign_key "public.requests", "public.request_groups"
  add_foreign_key "public.requests", "public.users", column: "created_by_id"

end
