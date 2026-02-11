# frozen_string_literal: true

FactoryBot.define do
  factory :request do
    project
    original_input { "Add a dark mode toggle to the settings page" }
    status { "plan_ready" }

    trait :plan_ready do
      status { "plan_ready" }
      planning_agent_id { "agent-planning-#{SecureRandom.hex(4)}" }
      after(:create) do |request|
        create(:plan, request: request)
      end
    end

    trait :execution_in_progress do
      status { "execution_in_progress" }
      execution_agent_id { "agent-execution-#{SecureRandom.hex(4)}" }
      after(:create) do |request|
        create(:plan, request: request)
      end
    end

    trait :completed do
      status { "completed" }
      request_type { :new_feature }
      execution_agent_id { "agent-execution-#{SecureRandom.hex(4)}" }
      after(:create) do |request|
        create(:plan, request: request)
        create(:execution, request: request)
      end
    end

    trait :with_design_input do
      requires_design_input { true }
    end
  end
end
