# frozen_string_literal: true

FactoryBot.define do
  factory :comment do
    request
    author_type { "user" }
    author_name { "Test User" }
    content { "This looks good, please proceed." }
    phase { "intake" }

    trait :from_agent do
      author_type { "agent" }
      author_name { "Agent" }
      content { "I've updated the brief based on your feedback." }
    end
  end
end
