# frozen_string_literal: true

class Plan < ApplicationRecord
  belongs_to :request

  before_create :set_version

  private

  def set_version
    self.version = (request.plans.maximum(:version) || 0) + 1
  end
end
