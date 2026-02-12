# frozen_string_literal: true

FactoryBot.define do
  factory :project do
    sequence(:name) { |n| "Test Project #{n}" }
    repo_url { "https://github.com/test/repo" }
    default_branch { "main" }
    context_docs { "This is a test project for Nova Flow Intake & Shape." }

    trait :with_asana do
      asana_workspace_gid { "1234567890" }
      asana_project_gid { "9876543210" }
    end
  end
end
