# frozen_string_literal: true

class AddAgentMessageCountAtFollowup < ActiveRecord::Migration[8.1]
  def change
    add_column :requests, :agent_message_count_at_followup, :integer
    add_column :decomposition_plans, :agent_message_count_at_followup, :integer
  end
end
