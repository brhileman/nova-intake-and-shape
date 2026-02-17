# frozen_string_literal: true

# Request represents a shaped task created through the intake flow.
# After the agent drafts a plan, the user reviews/edits it, optionally
# chats with the agent for refinement, then sends it to Asana.
#
# Status flow: draft -> sent_to_asana
class Request < ApplicationRecord
  belongs_to :project
  belongs_to :created_by, class_name: "User", optional: true
  has_many :comments, dependent: :destroy

  # Request type classification
  enum :request_type, { new_feature: 0, update: 1, fix: 2, chore: 3 }, prefix: true

  # Status
  STATUSES = %w[draft sent_to_asana].freeze

  validates :original_input, presence: true
  validates :request_number, uniqueness: { scope: :project_id }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }

  # Scopes for filtering
  scope :created_by_user, ->(user) { where(created_by: user) }
  scope :recent, -> { order(created_at: :desc) }
  scope :drafts, -> { where(status: "draft") }
  scope :sent, -> { where(status: "sent_to_asana") }

  # Auto-assign request number on creation (scoped to project)
  before_create :assign_request_number

  # Status helpers
  def draft?
    status == "draft"
  end

  def sent_to_asana?
    status == "sent_to_asana"
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

  # Whether this shaped task was successfully pushed to Asana
  def pushed_to_asana?
    asana_task_gid.present?
  end

  # Full Asana task URL
  def asana_url
    asana_task_url.presence || (asana_task_gid.present? ? "https://app.asana.com/0/0/#{asana_task_gid}" : nil)
  end

  # Whether the agent can receive follow-up messages
  def agent_available?
    intake_agent_id.present?
  end

  private

  def assign_request_number
    max_number = project.requests.maximum(:request_number) || 0
    self.request_number = max_number + 1
  end
end
