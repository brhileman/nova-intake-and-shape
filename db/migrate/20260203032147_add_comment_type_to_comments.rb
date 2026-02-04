class AddCommentTypeToComments < ActiveRecord::Migration[8.1]
  def change
    add_column :comments, :comment_type, :string, default: "agent_chat", null: false
    add_index :comments, :comment_type
  end
end
