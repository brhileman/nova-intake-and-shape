class CreatePlans < ActiveRecord::Migration[8.0]
  def change
    create_table :plans do |t|
      t.references :request, null: false, foreign_key: true
      t.integer :version, default: 1
      t.text :content

      t.timestamps
    end
  end
end
