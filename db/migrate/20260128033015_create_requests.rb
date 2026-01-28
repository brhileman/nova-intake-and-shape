class CreateRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :requests do |t|
      t.references :project, null: false, foreign_key: true
      t.text :original_input, null: false
      t.string :status, default: 'intake_pending'
      t.boolean :requires_design_input, default: false
      t.string :current_agent_id

      t.timestamps
    end

    add_index :requests, :status
  end
end
