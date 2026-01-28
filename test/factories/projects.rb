# frozen_string_literal: true

FactoryBot.define do
  factory :project do
    sequence(:name) { |n| "Test Project #{n}" }
    repo_url { "https://github.com/test/repo" }
    default_branch { "main" }
    environment_configured { true }
    context_docs { "This is a test project for Nova Flow." }
  end
end
