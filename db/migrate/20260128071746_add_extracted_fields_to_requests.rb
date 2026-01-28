class AddExtractedFieldsToRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :requests, :generated_title, :string
    add_column :requests, :user_story_persona, :string
    add_column :requests, :user_story_action, :text
    add_column :requests, :user_story_outcome, :text
    add_column :requests, :bug_summary, :text
    add_column :requests, :estimate_days, :decimal
  end
end
