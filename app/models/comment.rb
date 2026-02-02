# frozen_string_literal: true

class Comment < ApplicationRecord
  belongs_to :request
  belongs_to :user, optional: true

  validates :content, presence: true
  validates :author_type, inclusion: { in: %w[user agent] }
  validates :phase, inclusion: { in: %w[intake planning execution] }

  # Display name: prefer user name, fall back to author_name
  def display_author_name
    user&.name || author_name || "Unknown"
  end
end
