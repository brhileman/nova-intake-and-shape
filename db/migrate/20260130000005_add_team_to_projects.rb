# frozen_string_literal: true

class AddTeamToProjects < ActiveRecord::Migration[8.1]
  def change
    # Each project has a designated PM, Designer, and Dev
    add_reference :projects, :pm, foreign_key: { to_table: :users }
    add_reference :projects, :designer, foreign_key: { to_table: :users }
    add_reference :projects, :dev, foreign_key: { to_table: :users }
  end
end
