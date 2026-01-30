# frozen_string_literal: true

class DesignGuidance < ApplicationRecord
  belongs_to :request

  has_many_attached :images

  validates :request, uniqueness: true

  before_save :set_provided_at

  # Check if guidance has been provided (has images or specifications)
  def provided?
    images.attached? || specifications.present?
  end

  # Get image URLs for API consumption (returns array of public URLs)
  def image_urls
    return [] unless images.attached?

    images.map do |image|
      Rails.application.routes.url_helpers.rails_blob_url(image, only_path: false)
    end
  end

  private

  def set_provided_at
    self.provided_at ||= Time.current if provided?
  end
end
