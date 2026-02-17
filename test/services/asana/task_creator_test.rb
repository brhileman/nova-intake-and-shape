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

    # Stub custom fields lookup — return an LPL Status enum field
    stub_request(:get, %r{app\.asana\.com/api/1.0/projects/.+/custom_field_settings})
      .to_return(
        status: 200,
        body: {
          data: [
            {
              custom_field: {
                gid: "cf-lpl-status",
                name: "LPL Status",
                type: "enum",
                enum_options: [
                  { gid: "opt-backlog", name: "Backlog" },
                  { gid: "opt-shaping", name: "Shaping" },
                  { gid: "opt-ready", name: "Ready" }
                ]
              }
            }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

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

  test "creates Asana task with title only as name (no type prefix)" do
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

    # Verify name is just the title — no [New] prefix
    assert_requested(:post, "https://app.asana.com/api/1.0/tasks") do |req|
      body = JSON.parse(req.body)
      body.dig("data", "projects")&.include?(@project.asana_project_gid) &&
        body.dig("data", "name") == "Add Dark Mode Toggle"
    end
  end

  test "task name has no type prefix for fix requests" do
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
      body.dig("data", "name") == "Fix Login Bug"
    end
  end

  test "sends html_notes with rich formatting (not plain-text notes)" do
    request_record = create(:request, project: @project,
      original_input: "I need dark mode",
      generated_title: "Dark Mode")

    creator = Asana::TaskCreator.new(
      project: @project,
      request: request_record,
      plan_content: @plan_content
    )

    creator.create_task

    assert_requested(:post, "https://app.asana.com/api/1.0/tasks") do |req|
      body = JSON.parse(req.body)
      html_notes = body.dig("data", "html_notes")

      # Should use html_notes, not plain-text notes
      html_notes.present? &&
        body.dig("data", "notes").nil? &&
        # Wrapped in <body> tags (required by Asana)
        html_notes.start_with?("<body>") &&
        html_notes.end_with?("</body>") &&
        # Contains rendered HTML — not raw markdown
        html_notes.include?("<strong>") &&
        html_notes.include?("Acceptance Criteria") &&
        # Title line is still stripped
        !html_notes.include?("Add Dark Mode Toggle")
    end
  end

  test "sets LPL Status custom field to Shaping" do
    request_record = create(:request, project: @project,
      generated_title: "Add Dark Mode Toggle")

    creator = Asana::TaskCreator.new(
      project: @project,
      request: request_record,
      plan_content: @plan_content
    )

    creator.create_task

    assert_requested(:post, "https://app.asana.com/api/1.0/tasks") do |req|
      body = JSON.parse(req.body)
      custom_fields = body.dig("data", "custom_fields")
      custom_fields.present? && custom_fields["cf-lpl-status"] == "opt-shaping"
    end
  end

  test "gracefully handles missing LPL Status custom field" do
    # Override the custom fields stub to return no matching field
    stub_request(:get, %r{app\.asana\.com/api/1.0/projects/.+/custom_field_settings})
      .to_return(
        status: 200,
        body: { data: [] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    request_record = create(:request, project: @project,
      generated_title: "Add Dark Mode Toggle")

    creator = Asana::TaskCreator.new(
      project: @project,
      request: request_record,
      plan_content: @plan_content
    )

    # Should not raise — just skips custom fields
    result = creator.create_task
    assert_equal "created-task-123", result[:gid]
  end
end
