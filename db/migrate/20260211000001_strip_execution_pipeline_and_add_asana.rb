# frozen_string_literal: true

# Major migration: Strip execution/build pipeline, add Asana integration.
# This transforms Nova Flow from a full task planning + execution tool
# into a focused intake & shape tool that pushes tasks to Asana.
class StripExecutionPipelineAndAddAsana < ActiveRecord::Migration[8.1]
  def change
    # --- Drop execution pipeline tables ---
    drop_table :executions, if_exists: true
    drop_table :plans, if_exists: true
    drop_table :decomposition_plans, if_exists: true
    drop_table :approvals, if_exists: true
    drop_table :design_guidances, if_exists: true
    drop_table :figma_links, if_exists: true
    drop_table :technical_guidances, if_exists: true
    drop_table :request_groups, if_exists: true

    # --- Simplify requests table ---
    change_table :requests do |t|
      # Remove execution/planning columns
      t.remove :execution_agent_id, type: :string, if_exists: true
      t.remove :planning_agent_id, type: :string, if_exists: true
      t.remove :requires_design_input, type: :boolean, if_exists: true
      t.remove :position, type: :integer, if_exists: true
      t.remove :request_group_id, type: :bigint, if_exists: true
      t.remove :dependencies, type: :text, if_exists: true
      t.remove :agent_message_count_at_followup, type: :integer, if_exists: true
      t.remove :status, type: :string, if_exists: true
      t.remove :priority, type: :integer, if_exists: true

      # Add Asana integration columns
      t.string :asana_task_gid
      t.string :asana_task_url

      # Add plan content (stored inline instead of separate plans table)
      t.text :plan_content
    end

    add_index :requests, :asana_task_gid, unique: true, where: "asana_task_gid IS NOT NULL"

    # --- Simplify projects table ---
    change_table :projects do |t|
      # Remove execution-related columns
      t.remove :environment_configured, type: :boolean, if_exists: true
      t.remove :designer_id, type: :bigint, if_exists: true
      t.remove :dev_id, type: :bigint, if_exists: true

      # Add Asana integration columns
      t.string :asana_project_gid
      t.string :asana_workspace_gid
    end
  end
end
