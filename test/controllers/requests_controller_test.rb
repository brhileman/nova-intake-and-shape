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
    request = create(:request, :intake_in_progress, project: @project)

    get request_path(request)

    assert_response :success
    assert_select "h3", text: /Intake Conversation/
  end

  test "GET /requests/:id shows artifacts when available" do
    request = create(:request, :planning_review, project: @project)

    get request_path(request)

    assert_response :success
    assert_select "h3", text: "Brief"
  end

  # ===================
  # Create Tests
  # ===================

  test "GET /requests/new shows form" do
    get new_request_path

    assert_response :success
    assert_select "textarea[name='request[original_input]']"
  end

  test "POST /requests creates request and launches intake agent" do
    assert_difference("Request.count", 1) do
      post requests_path, params: {
        request: { original_input: "Add dark mode toggle" }
      }
    end

    request = Request.last
    assert_equal "intake_in_progress", request.status
    assert_not_nil request.current_agent_id
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
  # Approve Tests
  # ===================

  test "POST /requests/:id/approve from intake_review advances to planning" do
    request = create(:request, :intake_review, project: @project)

    post approve_request_path(request)

    request.reload
    assert request.status.start_with?("planning")
    assert_redirected_to request_path(request)
  end

  test "POST /requests/:id/approve from planning_review advances to execution" do
    request = create(:request, :planning_review, project: @project)

    post approve_request_path(request)

    request.reload
    assert request.status.start_with?("execution")
    assert_redirected_to request_path(request)
  end

  test "POST /requests/:id/approve from execution_review completes request" do
    request = create(:request, :execution_review, project: @project)

    post approve_request_path(request)

    request.reload
    assert_equal "completed", request.status
    assert_redirected_to request_path(request)
  end

  test "POST /requests/:id/approve from in_progress marks phase complete" do
    request = create(:request, :intake_in_progress, project: @project)

    post approve_request_path(request)

    request.reload
    assert_equal "intake_review", request.status
    assert_redirected_to request_path(request)
  end

  # ===================
  # Comment Tests
  # ===================

  test "POST /requests/:id/comment creates comment and sends to agent" do
    request = create(:request, :intake_review, project: @project)

    assert_difference("Comment.count", 1) do
      post comment_request_path(request), params: { message: "Please clarify" }
    end

    comment = Comment.last
    assert_equal "user", comment.author_type
    assert_equal "Please clarify", comment.content
    assert_equal "intake", comment.phase
  end

  # ===================
  # Refresh Tests
  # ===================

  test "GET /requests/:id/poll returns turbo stream" do
    request = create(:request, :intake_in_progress, project: @project)

    get poll_request_path(request), headers: {
      "Accept" => "text/vnd.turbo-stream.html"
    }

    assert_response :success
    assert_includes response.content_type, "turbo-stream"
  end
end
