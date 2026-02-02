# frozen_string_literal: true

class AddAssigneeToRequests < ActiveRecord::Migration[8.1]
  def change
    # add_reference already creates an index by default
    add_reference :requests, :assignee, foreign_key: { to_table: :users }
  end
end
