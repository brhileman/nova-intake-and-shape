# frozen_string_literal: true

class Project < ApplicationRecord
  has_many :requests, dependent: :destroy

  # Project owner
  belongs_to :pm, class_name: "User", optional: true

  validates :name, presence: true
  validates :repo_url, presence: true
  validate :asana_project_gid_differs_from_workspace_gid

  # Check if Asana integration is configured
  def asana_configured?
    asana_project_gid.present?
  end

  # Get the Asana access token (per-project or fall back to ENV)
  def asana_access_token
    # Per-project PAT would go here in the future
    ENV["ASANA_ACCESS_TOKEN"]
  end

  private

  def asana_project_gid_differs_from_workspace_gid
    return unless asana_project_gid.present? && asana_workspace_gid.present?

    if asana_project_gid == asana_workspace_gid
      errors.add(:asana_project_gid, "cannot be the same as the workspace GID — select an Asana project, not the workspace")
    end
  end
end
