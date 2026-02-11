# frozen_string_literal: true

class CreateFigmaLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :figma_links do |t|
      t.references :design_guidance, null: false, foreign_key: true
      t.string :url, null: false
      t.text :description
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :figma_links, [:design_guidance_id, :position]
  end
end
