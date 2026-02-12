# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class Asana::TaskCreatorTest < ActiveSupport::TestCase
  include FactoryBot::Syntax::Methods

  setup do
    @project = create(:project, :with_asana)
    @plan_content = <<~PLAN
      ## Implementation Plan

      **Title:** Add Dark Mode Toggle

      **Type:** new

      **Estimate (Dev Days):** 2.0

      **As a** user
      **I want** to toggle dark mode
      **So that** I can use the app in low light

      ## Acceptance Criteria
      - [ ] Toggle switch in settings
      - [ ] Preference persisted
    PLAN

    ENV["ASANA_ACCESS_TOKEN"] = "test-token"

    stub_request(:post, "https://app.asana.com/api/1.0/tasks")
      .to_return(
        status: 201,
        body: {
          data: {
            gid: "created-task-123",
            permalink_url: "https://app.asana.com/0/0/created-task-123"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  teardown do
    ENV.delete("ASANA_ACCESS_TOKEN")
  end

  test "creates Asana task with correct name" do
    request_record = create(:request, project: @project,
      generated_title: "Add Dark Mode Toggle",
      request_type: :new_feature)

    creator = Asana::TaskCreator.new(
      project: @project,
      request: request_record,
      plan_content: @plan_content
    )

    result = creator.create_task

    assert_equal "created-task-123", result[:gid]
    assert_equal "https://app.asana.com/0/0/created-task-123", result[:url]

    # Verify the request was sent with the correct project GID
    assert_requested(:post, "https://app.asana.com/api/1.0/tasks") do |req|
      body = JSON.parse(req.body)
      body.dig("data", "projects")&.include?(@project.asana_project_gid) &&
        body.dig("data", "name")&.include?("Add Dark Mode Toggle")
    end
  end

  test "includes type prefix in task name" do
    request_record = create(:request, project: @project,
      generated_title: "Fix Login Bug",
      request_type: :fix)

    creator = Asana::TaskCreator.new(
      project: @project,
      request: request_record,
      plan_content: "Fix plan"
    )

    creator.create_task

    assert_requested(:post, "https://app.asana.com/api/1.0/tasks") do |req|
      body = JSON.parse(req.body)
      body.dig("data", "name") == "[Fix] Fix Login Bug"
    end
  end

  test "includes plan content and original request in notes" do
    request_record = create(:request, project: @project,
      original_input: "I need dark mode",
      generated_title: "Dark Mode",
      user_story_persona: "a user",
      user_story_action: "toggle dark mode",
      user_story_outcome: "use the app in low light")

    creator = Asana::TaskCreator.new(
      project: @project,
      request: request_record,
      plan_content: @plan_content
    )

    creator.create_task

    assert_requested(:post, "https://app.asana.com/api/1.0/tasks") do |req|
      body = JSON.parse(req.body)
      notes = body.dig("data", "notes")
      notes.include?("As a a user") &&
        notes.include?("I need dark mode") &&
        notes.include?("Implementation Plan")
    end
  end
end
