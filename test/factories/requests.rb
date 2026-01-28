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

    trait :intake_review do
      status { "intake_review" }
      current_agent_id { "agent-intake-#{SecureRandom.hex(4)}" }
    end

    trait :planning_pending do
      status { "planning_pending" }
    end

    trait :planning_in_progress do
      status { "planning_in_progress" }
      current_agent_id { "agent-planning-#{SecureRandom.hex(4)}" }
    end

    trait :planning_review do
      status { "planning_review" }
      current_agent_id { "agent-planning-#{SecureRandom.hex(4)}" }
      after(:create) do |request|
        create(:brief, request: request)
      end
    end

    trait :execution_pending do
      status { "execution_pending" }
    end

    trait :execution_in_progress do
      status { "execution_in_progress" }
      current_agent_id { "agent-execution-#{SecureRandom.hex(4)}" }
      after(:create) do |request|
        create(:brief, request: request)
        create(:plan, request: request)
      end
    end

    trait :execution_review do
      status { "execution_review" }
      current_agent_id { "agent-execution-#{SecureRandom.hex(4)}" }
      after(:create) do |request|
        create(:brief, request: request)
        create(:plan, request: request)
      end
    end

    trait :completed do
      status { "completed" }
      request_type { :new_feature }
      after(:create) do |request|
        create(:brief, request: request)
        create(:plan, request: request)
        create(:execution, request: request)
      end
    end

    trait :with_design_input do
      requires_design_input { true }
    end
  end
end
