# frozen_string_literal: true

class CreateApprovals < ActiveRecord::Migration[8.1]
  def change
    create_table :approvals do |t|
      t.references :request, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :phase, null: false  # "brief", "plan", "execution"

      t.timestamps
    end

    # Prevent duplicate approvals: one approval per user per phase per request
    add_index :approvals, [:request_id, :user_id, :phase], unique: true, name: "index_approvals_uniqueness"
    add_index :approvals, :phase
  end
end
