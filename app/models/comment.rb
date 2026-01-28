# frozen_string_literal: true

class Comment < ApplicationRecord
  belongs_to :request

  validates :content, presence: true
  validates :author_type, inclusion: { in: %w[user agent] }
  validates :phase, inclusion: { in: %w[intake planning execution] }
end
