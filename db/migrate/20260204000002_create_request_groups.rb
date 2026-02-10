# frozen_string_literal: true

class CreateRequestGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :request_groups do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :decomposition_plan, foreign_key: true

      t.timestamps
    end

    add_index :request_groups, [:project_id, :name], unique: true
  end
end
