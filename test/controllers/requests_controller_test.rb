# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class RequestsControllerTest < ActionDispatch::IntegrationTest
  include FactoryBot::Syntax::Methods

  setup do
    @project = create(:project)

    # Mock all Cursor API calls
    stub_request(:any, %r{api\.cursor\.com})
      .to_return(
        status: 200,
        body: { id: "test-agent", status: "running", messages: [] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # ===================
  # Index Tests
  # ===================

  test "GET /requests lists all shaped tasks" do
    create_list(:request, 3, project: @project)

    get requests_path

    assert_response :success
    assert_select "a[href*='requests/']", minimum: 3
  end

  test "GET /requests shows empty state when no requests" do
    get requests_path

    assert_response :success
    assert_select "h3", text: "No shaped tasks yet"
  end

  # ===================
  # Show Tests
  # ===================

  test "GET /requests/:id shows shaped task details" do
    request_record = create(:request, :with_plan, project: @project)

    get request_path(request_record)

    assert_response :success
  end

  test "GET /requests/:id shows Asana link when pushed" do
    request_record = create(:request, :pushed_to_asana, project: @project)

    get request_path(request_record)

    assert_response :success
    assert_select "a[href*='asana.com']"
  end

  # ===================
  # Create Tests
  # ===================

  test "GET /requests/new shows intake form" do
    get new_request_path

    assert_response :success
  end

  test "POST /requests creates request with plan content" do
    assert_difference("Request.count", 1) do
      post requests_path, params: {
        request: { original_input: "Add dark mode toggle" },
        plan_content: "## Implementation Plan\n\n**Title:** Add Dark Mode\n\n**Type:** new"
      }
    end

    request_record = Request.last
    assert_equal "Add dark mode toggle", request_record.original_input
    assert request_record.plan_content.present?
    assert_redirected_to request_path(request_record)
  end

  test "POST /requests extracts structured fields from plan" do
    post requests_path, params: {
      request: { original_input: "Add dark mode toggle" },
      plan_content: "**Title:** Dark Mode Toggle\n\n**Type:** new\n\n**Estimate (Dev Days):** 2.5"
    }

    request_record = Request.last
    assert_equal "Dark Mode Toggle", request_record.generated_title
    assert_equal "new_feature", request_record.request_type
    assert_equal 2.5, request_record.estimate_days
  end

  test "POST /requests pushes to Asana when project is configured" do
    asana_project = create(:project, :with_asana)
    # Switch to the Asana-configured project
    post select_project_path(asana_project)

    # Mock Asana API
    stub_request(:post, "https://app.asana.com/api/1.0/tasks")
      .to_return(
        status: 201,
        body: { data: { gid: "asana-123", permalink_url: "https://app.asana.com/0/0/asana-123" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    post requests_path, params: {
      request: { original_input: "Add dark mode" },
      plan_content: "## Plan\n\n**Title:** Dark Mode"
    }

    request_record = Request.last
    assert_equal "asana-123", request_record.asana_task_gid
    assert request_record.pushed_to_asana?
  end

  test "POST /requests with invalid data re-renders form" do
    assert_no_difference("Request.count") do
      post requests_path, params: {
        request: { original_input: "" }
      }
    end

    assert_response :unprocessable_entity
  end
end
