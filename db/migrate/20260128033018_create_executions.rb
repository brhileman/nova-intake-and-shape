class CreateExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :executions do |t|
      t.references :request, null: false, foreign_key: true
      t.string :pr_url
      t.string :preview_url
      t.text :summary

      t.timestamps
    end
  end
end
