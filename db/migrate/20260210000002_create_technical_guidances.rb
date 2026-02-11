# frozen_string_literal: true

class CreateTechnicalGuidances < ActiveRecord::Migration[8.1]
  def change
    create_table :technical_guidances do |t|
      t.references :request, null: false, foreign_key: true, index: { unique: true }
      t.text :notes
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end
  end
end
