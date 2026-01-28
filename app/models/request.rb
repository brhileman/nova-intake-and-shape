# frozen_string_literal: true

class Request < ApplicationRecord
  include AASM

  belongs_to :project
  has_many :briefs, dependent: :destroy
  has_many :plans, dependent: :destroy
  has_one :execution, dependent: :destroy
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
    state :intake_review
    state :planning_pending
    state :planning_in_progress
    state :planning_review
    state :execution_pending
    state :execution_in_progress
    state :execution_review
    state :completed

    # Intake flow
    event :start_intake do
      transitions from: :intake_pending, to: :intake_in_progress
    end

    event :complete_intake do
      transitions from: :intake_in_progress, to: :intake_review
    end

    event :approve_intake do
      transitions from: :intake_review, to: :planning_pending
    end

    event :revise_intake do
      transitions from: :intake_review, to: :intake_in_progress
    end

    # Planning flow
    event :start_planning do
      transitions from: :planning_pending, to: :planning_in_progress
    end

    event :complete_planning do
      transitions from: :planning_in_progress, to: :planning_review
    end

    event :approve_plan do
      transitions from: :planning_review, to: :execution_pending
    end

    event :revise_plan do
      transitions from: :planning_review, to: :planning_in_progress
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
