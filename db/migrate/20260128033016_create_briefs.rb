class CreateBriefs < ActiveRecord::Migration[8.0]
  def change
    create_table :briefs do |t|
      t.references :request, null: false, foreign_key: true
      t.integer :version, default: 1
      t.text :content

      t.timestamps
    end
  end
end
