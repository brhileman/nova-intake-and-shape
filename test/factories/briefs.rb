# frozen_string_literal: true

FactoryBot.define do
  factory :brief do
    request
    sequence(:version) { |n| n }
    content do
      <<~CONTENT
        **Type:** new

        **As a** user
        **I want** to add a dark mode toggle to the settings page
        **So that** I can use the app comfortably in low-light environments

        ## Additional Notes
        - Should persist user preference
        - Should apply to all pages
      CONTENT
    end
  end
end
