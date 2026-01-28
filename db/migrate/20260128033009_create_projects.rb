class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :repo_url, null: false
      t.string :default_branch, default: 'main'
      t.text :context_docs
      t.boolean :environment_configured, default: false

      t.timestamps
    end
  end
end
