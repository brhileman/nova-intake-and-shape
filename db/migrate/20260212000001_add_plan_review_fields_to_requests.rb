# frozen_string_literal: true

# Add fields to support the plan review step between shaping and Asana push.
# - intake_agent_id: stores the Cursor agent ID so we can send follow-ups
# - status: tracks whether the shaped task is still being refined (draft) or sent
class AddPlanReviewFieldsToRequests < ActiveRecord::Migration[8.1]
  def change
    change_table :requests do |t|
      t.string :intake_agent_id
      t.string :status, default: "draft"
    end

    add_index :requests, :status
  end
end
