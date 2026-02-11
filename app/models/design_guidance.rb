# frozen_string_literal: true

class DesignGuidance < ApplicationRecord
  belongs_to :request
  belongs_to :user, optional: true

  has_many_attached :images
  has_many :figma_links, dependent: :destroy

  accepts_nested_attributes_for :figma_links, allow_destroy: true, reject_if: :all_blank

  validates :request, uniqueness: true

  before_save :set_provided_at

  # Display name: prefer user name, fall back to provided_by
  def display_provider_name
    user&.name || provided_by || "Unknown"
  end

  # Check if guidance has been provided (has images, specifications, or figma links)
  def provided?
    images.attached? || specifications.present? || figma_links.any?
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
