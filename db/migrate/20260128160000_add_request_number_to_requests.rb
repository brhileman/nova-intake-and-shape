# frozen_string_literal: true

class AddRequestNumberToRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :requests, :request_number, :integer

    # Add unique index scoped to project
    add_index :requests, [:project_id, :request_number], unique: true

    # Backfill existing requests with sequential numbers per project
    reversible do |dir|
      dir.up do
        execute <<-SQL
          WITH numbered_requests AS (
            SELECT id, project_id,
                   ROW_NUMBER() OVER (PARTITION BY project_id ORDER BY created_at) AS seq_num
            FROM requests
          )
          UPDATE requests
          SET request_number = numbered_requests.seq_num
          FROM numbered_requests
          WHERE requests.id = numbered_requests.id
        SQL
      end
    end
  end
end
