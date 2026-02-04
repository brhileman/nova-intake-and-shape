# frozen_string_literal: true

class Request < ApplicationRecord
  include AASM

  belongs_to :project
  belongs_to :created_by, class_name: "User", optional: true
  has_many :briefs, dependent: :destroy
  has_many :plans, dependent: :destroy
  has_one :execution, dependent: :destroy
  has_one :design_guidance, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :approvals, dependent: :destroy

  # Request type classification: new feature, update to existing, or bug fix
  enum :request_type, { new_feature: 0, update: 1, fix: 2 }, prefix: true

  validates :original_input, presence: true
  validates :request_number, uniqueness: { scope: :project_id }, allow_nil: true

  # Scopes for filtering
  scope :created_by_user, ->(user) { where(created_by: user) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_phase, ->(phase) { where("status LIKE ?", "#{phase}%") }
  scope :in_review, -> { where("status LIKE '%_clarified' OR status LIKE '%_review'") }

  # Scope for requests where user is on the project team
  scope :for_team_member, ->(user) {
    return none unless user

    joins(:project).where(
      "projects.pm_id = :user_id OR projects.designer_id = :user_id OR projects.dev_id = :user_id",
      user_id: user.id
    )
  }

  # Scope for requests that need action from a specific user (based on role AND project assignment)
  scope :needs_action_from, ->(user) {
    return none unless user

    # First, filter to projects where this user is assigned to the matching role
    base_scope = case user.role
    when "pm"
      joins(:project).where(projects: { pm_id: user.id })
    when "dev"
      joins(:project).where(projects: { dev_id: user.id })
    when "designer"
      joins(:project).where(projects: { designer_id: user.id })
    else
      none
    end

    case user.role
    when "pm"
      # PM needs to approve: briefs (intake_clarified) and plans (planning_clarified, if not yet approved by PM)
      base_scope
        .left_joins(:approvals)
        .where(status: ["intake_clarified", "planning_clarified"])
        .where.not(
          id: Approval.where(phase: ["brief", "plan"])
                      .joins(:user)
                      .where(users: { role: :pm })
                      .select(:request_id)
        )
        .distinct
    when "dev"
      # Dev needs to approve: plans (planning_clarified, if not yet approved by dev) and execution (execution_review)
      base_scope
        .left_joins(:approvals)
        .where(status: ["planning_clarified", "execution_review"])
        .where.not(
          id: Approval.where(phase: ["plan", "execution"])
                      .joins(:user)
                      .where(users: { role: :dev })
                      .select(:request_id)
        )
        .distinct
    when "designer"
      # Designers don't have approval responsibilities, but might see requests needing design input
      base_scope.where(requires_design_input: true, status: ["intake_clarified", "planning_clarified"])
    else
      none
    end
  }

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

  # Check if user is on this request's team (via project assignment)
  def user_on_team?(user)
    return false unless user
    [project.pm, project.designer, project.dev].compact.include?(user)
  end

  # ========================================
  # Role-based approval methods
  # ========================================

  # Brief approval: requires PM only
  def brief_approved?
    approvals.for_brief.joins(:user).where(users: { role: :pm }).exists?
  end

  def brief_approval_status
    pm_approved = approvals.for_brief.joins(:user).where(users: { role: :pm }).first
    { pm: pm_approved }
  end

  # Plan approval: requires BOTH PM and Dev
  def plan_approved?
    pm_approved = approvals.for_plan.joins(:user).where(users: { role: :pm }).exists?
    dev_approved = approvals.for_plan.joins(:user).where(users: { role: :dev }).exists?
    pm_approved && dev_approved
  end

  def plan_approval_status
    pm_approval = approvals.for_plan.joins(:user).where(users: { role: :pm }).first
    dev_approval = approvals.for_plan.joins(:user).where(users: { role: :dev }).first
    { pm: pm_approval, dev: dev_approval }
  end

  # Execution approval: requires Dev only
  def execution_approved?
    approvals.for_execution.joins(:user).where(users: { role: :dev }).exists?
  end

  def execution_approval_status
    dev_approved = approvals.for_execution.joins(:user).where(users: { role: :dev }).first
    { dev: dev_approved }
  end

  # Check if a user can approve the current phase
  def can_user_approve?(user)
    return false unless user
    return false unless in_review_state?

    case status
    when "intake_clarified"
      user.can_approve_brief? && !user_has_approved_phase?(user, "brief")
    when "planning_clarified"
      user.can_approve_plan? && !user_has_approved_phase?(user, "plan")
    when "execution_review"
      user.can_approve_execution? && !user_has_approved_phase?(user, "execution")
    else
      false
    end
  end

  # Check if user has already approved the current phase
  def user_has_approved_phase?(user, phase)
    approvals.where(user: user, phase: phase).exists?
  end

  # Record an approval from a user
  def record_approval(user)
    phase = current_approval_phase
    return nil unless phase

    approvals.create(user: user, phase: phase)
  end

  # Get the current phase that needs approval
  def current_approval_phase
    case status
    when "intake_clarified" then "brief"
    when "planning_clarified" then "plan"
    when "execution_review" then "execution"
    end
  end

  # Check if all required approvals are present for the current phase
  def all_approvals_present?
    case status
    when "intake_clarified"
      brief_approved?
    when "planning_clarified"
      plan_approved?
    when "execution_review"
      execution_approved?
    else
      false
    end
  end

  private

  def assign_request_number
    max_number = project.requests.maximum(:request_number) || 0
    self.request_number = max_number + 1
  end
end
