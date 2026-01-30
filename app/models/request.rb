# frozen_string_literal: true

class Request < ApplicationRecord
  include AASM

  belongs_to :project
  has_many :briefs, dependent: :destroy
  has_many :plans, dependent: :destroy
  has_one :execution, dependent: :destroy
  has_one :design_guidance, dependent: :destroy
  has_many :comments, dependent: :destroy

  # Request type classification: new feature, update to existing, or bug fix
  enum :request_type, { new_feature: 0, update: 1, fix: 2 }, prefix: true

  validates :original_input, presence: true
  validates :request_number, uniqueness: { scope: :project_id }, allow_nil: true

  # Auto-assign request number on creation (scoped to project)
  before_create :assign_request_number

  aasm column: :status do
    state :intake_pending, initial: true
    state :intake_in_progress
    state :intake_needs_clarification  # Agent asked clarifying questions
    state :intake_clarified            # Brief extracted, ready for approval
    state :planning_pending
    state :planning_in_progress
    state :planning_needs_clarification  # Agent asked clarifying questions
    state :planning_clarified            # Plan extracted, ready for approval
    state :execution_pending
    state :execution_in_progress
    state :execution_review
    state :completed

    # Intake flow
    event :start_intake do
      transitions from: :intake_pending, to: :intake_in_progress
    end

    event :request_clarification do
      transitions from: :intake_in_progress, to: :intake_needs_clarification
      transitions from: :planning_in_progress, to: :planning_needs_clarification
    end

    event :clarify_intake do
      transitions from: :intake_in_progress, to: :intake_clarified
      transitions from: :intake_needs_clarification, to: :intake_clarified
    end

    event :approve_intake do
      transitions from: :intake_clarified, to: :planning_pending
    end

    event :revise_intake do
      transitions from: :intake_clarified, to: :intake_in_progress
      transitions from: :intake_needs_clarification, to: :intake_in_progress
    end

    # Planning flow
    event :start_planning do
      transitions from: :planning_pending, to: :planning_in_progress
    end

    event :clarify_planning do
      transitions from: :planning_in_progress, to: :planning_clarified
      transitions from: :planning_needs_clarification, to: :planning_clarified
    end

    event :approve_plan do
      transitions from: :planning_clarified, to: :execution_pending
    end

    event :revise_plan do
      transitions from: :planning_clarified, to: :planning_in_progress
      transitions from: :planning_needs_clarification, to: :planning_in_progress
    end

    # Execution flow
    event :start_execution do
      transitions from: :execution_pending, to: :execution_in_progress
    end

    event :complete_execution do
      transitions from: :execution_in_progress, to: :execution_review
    end

    event :approve_execution do
      transitions from: :execution_review, to: :completed
    end

    event :revise_execution do
      transitions from: :execution_review, to: :execution_in_progress
    end
  end

  # Helper to get current phase
  def current_phase
    status.to_s.split("_").first
  end

  # Check if request is awaiting user input (for polling logic)
  def awaiting_user_input?
    status.end_with?("_needs_clarification", "_clarified", "_review") || status == "completed"
  end

  # Check if request is in a review/approval state
  def in_review_state?
    status.end_with?("_clarified", "_review")
  end

  # Display title: prefer generated_title, fall back to original_input
  def display_title
    generated_title.presence || original_input.truncate(60)
  end

  # Formatted display title with request number prefix
  def numbered_title
    number_prefix = request_number ? "REQ-#{request_number}: " : ""
    "#{number_prefix}#{display_title}"
  end

  # Get the latest brief
  def latest_brief
    briefs.order(version: :desc).first
  end

  # Get the latest plan
  def latest_plan
    plans.order(version: :desc).first
  end

  private

  def assign_request_number
    max_number = project.requests.maximum(:request_number) || 0
    self.request_number = max_number + 1
  end
end
