# frozen_string_literal: true

class Project < ApplicationRecord
  has_many :requests, dependent: :destroy

  # Project team assignments
  belongs_to :pm, class_name: "User", optional: true
  belongs_to :designer, class_name: "User", optional: true
  belongs_to :dev, class_name: "User", optional: true

  validates :name, presence: true
  validates :repo_url, presence: true

  # Check if team is fully assigned
  def team_complete?
    pm.present? && designer.present? && dev.present?
  end

  # Get team members as array
  def team_members
    [pm, designer, dev].compact
  end
end
