# frozen_string_literal: true

FactoryBot.define do
  factory :plan do
    request
    sequence(:version) { |n| n }
    content do
      <<~CONTENT
        ## Implementation Plan

        ### 1. Create Theme Context
        - Add ThemeContext provider
        - Store preference in localStorage

        ### 2. Add Toggle Component
        - Create DarkModeToggle component
        - Place in settings page

        ### 3. Apply Styles
        - Add CSS variables for light/dark themes
        - Update Tailwind config

        ### 4. Testing
        - Add unit tests for toggle
        - Add e2e test for persistence
      CONTENT
    end
  end
end
