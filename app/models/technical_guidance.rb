# frozen_string_literal: true

class TechnicalGuidance < ApplicationRecord
  belongs_to :request
  belongs_to :user, optional: true

  validates :request, uniqueness: true

  # Check if guidance has been provided
  def provided?
    notes.present?
  end

  # Display name: prefer user name, fall back to "Unknown"
  def display_provider_name
    user&.name || "Unknown"
  end
end
