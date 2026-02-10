# frozen_string_literal: true

class DecompositionPlan < ApplicationRecord
  belongs_to :project
  belongs_to :created_by, class_name: "User", optional: true

  has_one :request_group, dependent: :nullify

  validates :original_input, presence: true

  # Status constants
  STATUSES = %w[planning needs_clarification ready approved cancelled].freeze

  validates :status, inclusion: { in: STATUSES }

  scope :for_project, ->(project) { where(project: project) }
  scope :active, -> { where(status: %w[planning needs_clarification ready]) }
  scope :by_status, ->(status) { where(status: status) }

  # Check if agent is currently working
  def agent_active?
    status == "planning" && agent_id.present?
  end

  # Check if plan is ready for approval
  def ready_for_approval?
    status == "ready" && plan_content.present?
  end

  # Check if plan has been approved
  def approved?
    status == "approved"
  end

  # Check if plan was cancelled
  def cancelled?
    status == "cancelled"
  end
end
