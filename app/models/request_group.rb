# frozen_string_literal: true

class RequestGroup < ApplicationRecord
  belongs_to :project
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :decomposition_plan, optional: true

  has_many :requests, dependent: :nullify

  validates :name, presence: true
  validates :name, uniqueness: { scope: :project_id, message: "already exists in this project" }

  scope :for_project, ->(project) { where(project: project) }
  scope :with_requests, -> { joins(:requests).distinct }
end
