# frozen_string_literal: true

FactoryBot.define do
  factory :request do
    project
    original_input { "Add a dark mode toggle to the settings page" }
    status { "intake_pending" }

    trait :intake_in_progress do
      status { "intake_in_progress" }
      current_agent_id { "agent-intake-#{SecureRandom.hex(4)}" }
    end

    trait :intake_needs_clarification do
      status { "intake_needs_clarification" }
      current_agent_id { "agent-intake-#{SecureRandom.hex(4)}" }
    end

    trait :plan_ready do
      status { "plan_ready" }
      current_agent_id { "agent-intake-#{SecureRandom.hex(4)}" }
      after(:create) do |request|
        create(:plan, request: request)
      end
    end

    trait :execution_pending do
      status { "execution_pending" }
    end

    trait :execution_in_progress do
      status { "execution_in_progress" }
      current_agent_id { "agent-execution-#{SecureRandom.hex(4)}" }
      after(:create) do |request|
        create(:plan, request: request)
      end
    end

    trait :execution_review do
      status { "execution_review" }
      current_agent_id { "agent-execution-#{SecureRandom.hex(4)}" }
      after(:create) do |request|
        create(:plan, request: request)
      end
    end

    trait :completed do
      status { "completed" }
      request_type { :new_feature }
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
