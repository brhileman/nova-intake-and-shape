# frozen_string_literal: true

class MigrateRequestStatuses < ActiveRecord::Migration[8.1]
  def up
    # Map old statuses to new simplified statuses
    # Old: intake_pending, intake_in_progress, intake_needs_clarification, plan_ready,
    #      execution_pending, execution_in_progress, execution_review, completed
    # New: plan_ready (planning), execution_in_progress, completed
    
    # All intake states become plan_ready (they're in planning phase)
    execute <<-SQL
      UPDATE requests 
      SET status = 'plan_ready' 
      WHERE status IN ('intake_pending', 'intake_in_progress', 'intake_needs_clarification')
    SQL
    
    # execution_pending and execution_review become execution_in_progress
    execute <<-SQL
      UPDATE requests 
      SET status = 'execution_in_progress' 
      WHERE status IN ('execution_pending', 'execution_review')
    SQL
    
    # plan_ready, execution_in_progress, and completed remain unchanged
  end

  def down
    # This is a one-way migration - we can't restore the original granular statuses
    # because we don't know what they were
  end
end
