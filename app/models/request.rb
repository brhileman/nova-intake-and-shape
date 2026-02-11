# frozen_string_literal: true

class Request < ApplicationRecord
  include AASM

  belongs_to :project
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :request_group, optional: true
  has_many :plans, dependent: :destroy
  has_one :execution, dependent: :destroy
  has_one :design_guidance, dependent: :destroy
  has_one :technical_guidance, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :approvals, dependent: :destroy

  # Request type classification
  enum :request_type, { new_feature: 0, update: 1, fix: 2, chore: 3 }, prefix: true

  # Priority level: high, medium, low
  enum :priority, { high: 0, medium: 1, low: 2 }, prefix: true

  validates :original_input, presence: true
  validates :request_number, uniqueness: { scope: :project_id }, allow_nil: true

  # Scopes for filtering
  scope :created_by_user, ->(user) { where(created_by: user) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_phase, ->(phase) { where("status LIKE ?", "#{phase}%") }
  scope :in_review, -> { where(status: "plan_ready") }
  scope :ordered_by_position, -> { order(created_at: :desc) }
  scope :in_group, ->(group) { where(request_group: group) }
  scope :ungrouped, -> { where(request_group_id: nil) }

  # Scope for requests where user is on the project team
  scope :for_team_member, ->(user) {
    return none unless user

    joins(:project).where(
      "projects.pm_id = :user_id OR projects.designer_id = :user_id OR projects.dev_id = :user_id",
      user_id: user.id
    )
  }

  # Scope for requests that need action from a specific user (based on role AND project assignment)
  # Simplified now that approvals are removed - just shows requests in planning phase
  scope :needs_action_from, ->(user) {
    return none unless user

    # Filter to projects where this user is assigned
    for_team_member(user).where(status: "plan_ready")
  }

  # Auto-assign request number and position on creation (scoped to project)
  before_create :assign_request_number
  before_create :assign_position

  # Simplified state machine - requests are created with plan_ready status
  # (intake is now ephemeral and happens before request creation)
  aasm column: :status do
    state :plan_ready, initial: true    # Request created with plan
    state :execution_in_progress        # Build is running
    state :completed                    # PR created, done

    # Start build - transitions from planning to execution
    event :start_build do
      transitions from: :plan_ready, to: :execution_in_progress
    end

    # Complete build - execution agent finished
    event :complete_build do
      transitions from: :execution_in_progress, to: :completed
    end
  end

  # Helper to get current phase
  def current_phase
    in_planning_phase? ? "planning" : "execution"
  end

  # Check if request is awaiting user input (for polling logic)
  def awaiting_user_input?
    plan_ready? || completed?
  end

  # Check if request is in the planning phase (for simplified UI)
  def in_planning_phase?
    plan_ready?
  end

  # Check if request is in the execution phase (for simplified UI)
  def in_execution_phase?
    execution_in_progress? || completed?
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

  # Get the latest plan
  def latest_plan
    plans.order(version: :desc).first
  end

  # Check if user is on this request's team (via project assignment)
  def user_on_team?(user)
    return false unless user
    [project.pm, project.designer, project.dev].compact.include?(user)
  end

  private

  def assign_request_number
    max_number = project.requests.maximum(:request_number) || 0
    self.request_number = max_number + 1
  end

  def assign_position
    return if position.present? # Don't overwrite if already set

    max_position = project.requests.maximum(:position) || 0
    self.position = max_position + 1
  end
end
