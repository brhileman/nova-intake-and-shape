# frozen_string_literal: true

FactoryBot.define do
  factory :request do
    project
    original_input { "Add a dark mode toggle to the settings page" }

    trait :with_plan do
      plan_content { "## Implementation Plan\n\n**Title:** Add Dark Mode Toggle\n\n**Type:** new" }
      generated_title { "Add Dark Mode Toggle" }
      request_type { :new_feature }
    end

    trait :pushed_to_asana do
      with_plan
      asana_task_gid { "asana-task-#{SecureRandom.hex(4)}" }
      asana_task_url { "https://app.asana.com/0/0/#{asana_task_gid}" }
    end
  end
end
