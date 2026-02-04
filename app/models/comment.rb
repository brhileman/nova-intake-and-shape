# frozen_string_literal: true

class Comment < ApplicationRecord
  belongs_to :request
  belongs_to :user, optional: true

  # Comment types
  COMMENT_TYPES = %w[agent_chat team].freeze

  validates :content, presence: true
  validates :author_type, inclusion: { in: %w[user agent] }
  validates :phase, inclusion: { in: %w[intake planning execution] }, allow_nil: true
  validates :comment_type, inclusion: { in: COMMENT_TYPES }

  # Scopes
  scope :agent_chat, -> { where(comment_type: "agent_chat") }
  scope :team, -> { where(comment_type: "team") }
  scope :for_phase, ->(phase) { where(phase: phase) }

  # Display name: prefer user name, fall back to author_name
  def display_author_name
    user&.name || author_name || "Unknown"
  end

  # Check if this is a team comment
  def team_comment?
    comment_type == "team"
  end

  # Check if this is an agent chat comment
  def agent_chat?
    comment_type == "agent_chat"
  end
end
