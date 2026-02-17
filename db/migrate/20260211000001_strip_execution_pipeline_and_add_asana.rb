# frozen_string_literal: true

# Major migration: Strip execution/build pipeline, add Asana integration.
# This transforms Nova Flow from a full task planning + execution tool
# into a focused intake & shape tool that pushes tasks to Asana.
class StripExecutionPipelineAndAddAsana < ActiveRecord::Migration[8.1]
  def change
    # --- Remove FK constraints before dropping tables ---
    if foreign_key_exists?(:requests, :request_groups)
      remove_foreign_key :requests, :request_groups
    end

    # --- Remove execution/planning columns from requests ---
    %i[
      execution_agent_id planning_agent_id requires_design_input
      position request_group_id dependencies
      agent_message_count_at_followup status priority
    ].each do |col|
      remove_column :requests, col if column_exists?(:requests, col)
    end

    # Add Asana integration columns to requests
    add_column :requests, :asana_task_gid, :string unless column_exists?(:requests, :asana_task_gid)
    add_column :requests, :asana_task_url, :string unless column_exists?(:requests, :asana_task_url)
    add_column :requests, :plan_content, :text unless column_exists?(:requests, :plan_content)

    unless index_exists?(:requests, :asana_task_gid)
      add_index :requests, :asana_task_gid, unique: true, where: "asana_task_gid IS NOT NULL"
    end

    # --- Drop execution pipeline tables (children before parents for FK safety) ---
    drop_table :figma_links, if_exists: true
    drop_table :technical_guidances, if_exists: true
    drop_table :design_guidances, if_exists: true
    drop_table :request_groups, if_exists: true
    drop_table :approvals, if_exists: true
    drop_table :executions, if_exists: true
    drop_table :plans, if_exists: true
    drop_table :decomposition_plans, if_exists: true

    # --- Simplify projects table ---
    %i[environment_configured designer_id dev_id].each do |col|
      remove_column :projects, col if column_exists?(:projects, col)
    end

    add_column :projects, :asana_project_gid, :string unless column_exists?(:projects, :asana_project_gid)
    add_column :projects, :asana_workspace_gid, :string unless column_exists?(:projects, :asana_workspace_gid)
  end
end
