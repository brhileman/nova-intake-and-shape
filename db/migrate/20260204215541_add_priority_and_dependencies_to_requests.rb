class AddPriorityAndDependenciesToRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :requests, :priority, :integer
    add_column :requests, :dependencies, :text
  end
end
