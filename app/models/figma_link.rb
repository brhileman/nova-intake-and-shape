# frozen_string_literal: true

class FigmaLink < ApplicationRecord
  belongs_to :design_guidance

  validates :url, presence: true

  default_scope { order(position: :asc) }
end
