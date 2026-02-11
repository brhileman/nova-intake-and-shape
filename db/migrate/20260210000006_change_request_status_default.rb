# frozen_string_literal: true

class ChangeRequestStatusDefault < ActiveRecord::Migration[8.1]
  def up
    change_column_default :requests, :status, from: "intake_pending", to: "plan_ready"
  end

  def down
    change_column_default :requests, :status, from: "plan_ready", to: "intake_pending"
  end
end
