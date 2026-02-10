# frozen_string_literal: true

class RenameBugSummaryToSummary < ActiveRecord::Migration[8.0]
  def change
    rename_column :requests, :bug_summary, :summary
  end
end
