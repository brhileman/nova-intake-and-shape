class AddRequestTypeToRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :requests, :request_type, :integer, default: 0
    add_index :requests, :request_type
  end
end
