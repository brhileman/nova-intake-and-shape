class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments do |t|
      t.references :request, null: false, foreign_key: true
      t.string :author_type
      t.string :author_name
      t.text :content
      t.string :phase

      t.timestamps
    end
  end
end
