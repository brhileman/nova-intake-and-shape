# frozen_string_literal: true

class AddGroupAndPositionToRequests < ActiveRecord::Migration[8.1]
  def change
    add_reference :requests, :request_group, foreign_key: true
    add_column :requests, :position, :integer

    add_index :requests, [:project_id, :position]
  end
end
