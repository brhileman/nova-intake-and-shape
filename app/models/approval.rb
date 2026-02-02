# frozen_string_literal: true

class Approval < ApplicationRecord
  PHASES = %w[brief plan execution].freeze

  belongs_to :request
  belongs_to :user

  validates :phase, presence: true, inclusion: { in: PHASES }
  validates :user_id, uniqueness: { scope: [:request_id, :phase], message: "has already approved this phase" }

  # Scopes for finding approvals by phase
  scope :for_brief, -> { where(phase: "brief") }
  scope :for_plan, -> { where(phase: "plan") }
  scope :for_execution, -> { where(phase: "execution") }

  # Check if this approval was made by a user with the required role
  def valid_for_phase?
    case phase
    when "brief"
      user.can_approve_brief?
    when "plan"
      user.can_approve_plan?
    when "execution"
      user.can_approve_execution?
    else
      false
    end
  end
end
