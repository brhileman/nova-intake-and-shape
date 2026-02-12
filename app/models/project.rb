# frozen_string_literal: true

class Project < ApplicationRecord
  has_many :requests, dependent: :destroy

  # Project owner
  belongs_to :pm, class_name: "User", optional: true

  validates :name, presence: true
  validates :repo_url, presence: true

  # Check if Asana integration is configured
  def asana_configured?
    asana_project_gid.present?
  end

  # Get the Asana access token (per-project or fall back to ENV)
  def asana_access_token
    # Per-project PAT would go here in the future
    ENV["ASANA_ACCESS_TOKEN"]
  end
end
