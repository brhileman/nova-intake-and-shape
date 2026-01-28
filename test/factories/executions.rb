# frozen_string_literal: true

FactoryBot.define do
  factory :execution do
    request
    pr_url { "https://github.com/test/repo/pull/42" }
    preview_url { "https://preview.test.com/pr-42" }
    summary do
      <<~SUMMARY
        Successfully implemented dark mode toggle:
        - Added ThemeContext provider
        - Created DarkModeToggle component
        - Updated CSS variables
        - Added tests
      SUMMARY
    end
  end
end
