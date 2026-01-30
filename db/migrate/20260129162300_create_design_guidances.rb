# frozen_string_literal: true

class CreateDesignGuidances < ActiveRecord::Migration[8.0]
  def change
    create_table :design_guidances do |t|
      t.references :request, null: false, foreign_key: true
      t.text :specifications
      t.string :figma_url
      t.string :provided_by
      t.datetime :provided_at

      t.timestamps
    end
  end
end
