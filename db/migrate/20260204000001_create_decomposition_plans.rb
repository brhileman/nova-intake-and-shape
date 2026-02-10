# frozen_string_literal: true

class CreateDecompositionPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :decomposition_plans do |t|
      t.references :project, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :title
      t.text :original_input, null: false
      t.string :agent_id
      t.string :status, default: "planning"
      t.text :plan_content

      t.timestamps
    end

    add_index :decomposition_plans, :status
    add_index :decomposition_plans, :agent_id
  end
end
