# frozen_string_literal: true

class AddPlanningAgentIdToRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :requests, :planning_agent_id, :string
    rename_column :requests, :current_agent_id, :execution_agent_id
  end
end
