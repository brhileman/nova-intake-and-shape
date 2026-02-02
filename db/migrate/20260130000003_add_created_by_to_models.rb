# frozen_string_literal: true

class AddCreatedByToModels < ActiveRecord::Migration[8.1]
  def change
    # Add created_by to requests, briefs, plans
    add_reference :requests, :created_by, foreign_key: { to_table: :users }
    add_reference :briefs, :created_by, foreign_key: { to_table: :users }
    add_reference :plans, :created_by, foreign_key: { to_table: :users }

    # Add user reference to comments and design_guidances
    add_reference :comments, :user, foreign_key: true
    add_reference :design_guidances, :user, foreign_key: true
  end
end
