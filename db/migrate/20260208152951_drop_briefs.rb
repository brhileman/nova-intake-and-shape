# frozen_string_literal: true

class DropBriefs < ActiveRecord::Migration[8.0]
  def up
    drop_table :briefs
  end

  def down
    create_table :briefs do |t|
      t.references :request, null: false, foreign_key: true
      t.text :content
      t.integer :version, default: 1
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end
  end
end
