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

  test "GET /requests lists all requests" do
    create_list(:request, 3, project: @project)

    get requests_path

    assert_response :success
    # 3 request links + 1-2 "New Request" links
    assert_select "a[href*='requests/']", minimum: 3
  end

  test "GET /requests shows empty state when no requests" do
    get requests_path

    assert_response :success
    assert_select "h3", text: "No requests"
  end

  # ===================
  # Show Tests
  # ===================

  test "GET /requests/:id shows request details" do
    request = create(:request, :plan_ready, project: @project)

    get request_path(request)

    assert_response :success
  end

  # ===================
  # Create Tests
  # ===================

  test "GET /requests/new shows intake form" do
    get new_request_path

    assert_response :success
  end

  test "POST /requests creates request with plan" do
    assert_difference("Request.count", 1) do
      post requests_path, params: {
        request: { original_input: "Add dark mode toggle" },
        plan_content: "## Plan\n\n1. Add toggle component"
      }
    end

    request = Request.last
    assert_equal "plan_ready", request.status
    assert request.latest_plan.present?
    assert_redirected_to request_path(request)
  end

  test "POST /requests with invalid data re-renders form" do
    assert_no_difference("Request.count") do
      post requests_path, params: {
        request: { original_input: "" }
      }
    end

    assert_response :unprocessable_entity
  end

  # ===================
  # Build Tests
  # ===================

  test "POST /requests/:id/build starts execution" do
    request = create(:request, :plan_ready, project: @project)

    post build_request_path(request)

    request.reload
    assert_equal "execution_in_progress", request.status
    assert_not_nil request.execution_agent_id
  end

  test "POST /requests/:id/build fails if not plan_ready" do
    request = create(:request, :execution_in_progress, project: @project)

    post build_request_path(request)

    request.reload
    assert_equal "execution_in_progress", request.status
  end

  # ===================
  # Update Plan Tests
  # ===================

  test "PATCH /requests/:id/update_plan saves plan content" do
    request = create(:request, :plan_ready, project: @project)

    patch update_plan_request_path(request), params: { plan_content: "Updated plan content" }

    assert_response :success
    request.reload
    assert_equal "Updated plan content", request.latest_plan.content
  end

  # ===================
  # Comment Tests
  # ===================

  test "POST /requests/:id/comment creates comment and sends to agent" do
    request = create(:request, :plan_ready, project: @project)
    request.update!(planning_agent_id: "test-agent-123")

    assert_difference("Comment.count", 1) do
      post comment_request_path(request), params: { message: "Please clarify" }
    end

    comment = Comment.last
    assert_equal "user", comment.author_type
    assert_equal "Please clarify", comment.content
    assert_equal "planning", comment.phase
  end

  # ===================
  # Poll Tests
  # ===================

  test "GET /requests/:id/poll returns turbo stream" do
    request = create(:request, :execution_in_progress, project: @project)

    get poll_request_path(request), headers: {
      "Accept" => "text/vnd.turbo-stream.html"
    }

    assert_response :success
    assert_includes response.content_type, "turbo-stream"
  end
end
