# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class RequestsControllerTest < ActionDispatch::IntegrationTest
  include FactoryBot::Syntax::Methods

  setup do
    @project = create(:project)

    # Select the project so current_project returns it
    post select_project_path(@project)

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

  test "GET /requests filters by drafts" do
    create(:request, project: @project, status: "draft")
    create(:request, :sent, project: @project)

    get requests_path(filter: "drafts")

    assert_response :success
  end

  test "GET /requests shows empty state when no requests" do
    get requests_path

    assert_response :success
    assert_select "h3", text: "No shaped tasks yet"
  end

  # ===================
  # Show Tests
  # ===================

  test "GET /requests/:id shows plan review page for draft" do
    request_record = create(:request, :with_plan, project: @project, status: "draft")

    get request_path(request_record)

    assert_response :success
    assert_select "h1", text: "Request Plan"
    assert_select "button", text: "Preview"
    assert_select "button", text: "Edit"
  end

  test "GET /requests/:id shows confirmation page when sent to Asana" do
    request_record = create(:request, :pushed_to_asana, project: @project)

    get request_path(request_record)

    assert_response :success
    assert_select "a[href*='asana.com']"
  end

  test "GET /requests/:id shows Send to Asana button for drafts with Asana configured" do
    asana_project = create(:project, :with_asana)
    post select_project_path(asana_project)

    request_record = create(:request, :with_plan, project: asana_project, status: "draft")

    get request_path(request_record)

    assert_response :success
    assert_select "button", text: /Send to Asana/
  end

  test "GET /requests/:id shows agent chat when agent available" do
    request_record = create(:request, :with_plan, :with_agent, project: @project, status: "draft")

    get request_path(request_record)

    assert_response :success
    assert_select "h2", text: "Chat with agent to update plan"
  end

  # ===================
  # Create Tests
  # ===================

  test "GET /requests/new shows intake form" do
    get new_request_path

    assert_response :success
  end

  test "POST /requests creates request in draft status" do
    assert_difference("Request.count", 1) do
      post requests_path, params: {
        request: { original_input: "Add dark mode toggle" },
        plan_content: "## Implementation Plan\n\n**Title:** Add Dark Mode\n\n**Type:** new"
      }, as: :json
    end

    request_record = @project.requests.order(:created_at).last
    assert_equal "draft", request_record.status
    assert_equal "Add dark mode toggle", request_record.original_input
    assert request_record.plan_content.present?
  end

  test "POST /requests stores agent_id on request" do
    post requests_path, params: {
      request: { original_input: "Add dark mode toggle" },
      plan_content: "## Plan\n\n**Title:** Dark Mode",
      agent_id: "agent-abc123"
    }, as: :json

    request_record = @project.requests.order(:created_at).last
    assert_equal "agent-abc123", request_record.intake_agent_id
  end

  test "POST /requests extracts structured fields from plan" do
    post requests_path, params: {
      request: { original_input: "Add dark mode toggle" },
      plan_content: "**Title:** Dark Mode Toggle\n\n**Type:** new\n\n**Estimate (Dev Days):** 2.5"
    }, as: :json

    request_record = @project.requests.order(:created_at).last
    assert_equal "Dark Mode Toggle", request_record.generated_title
    assert_equal "new_feature", request_record.request_type
    assert_equal 2.5, request_record.estimate_days
  end

  test "POST /requests does NOT push to Asana (draft status)" do
    asana_project = create(:project, :with_asana)
    post select_project_path(asana_project)

    post requests_path, params: {
      request: { original_input: "Add dark mode" },
      plan_content: "## Plan\n\n**Title:** Dark Mode"
    }, as: :json

    request_record = asana_project.requests.order(:created_at).last
    assert_equal "draft", request_record.status
    assert_nil request_record.asana_task_gid
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
  # Update Plan Tests
  # ===================

  test "PATCH /requests/:id/update_plan saves plan content" do
    request_record = create(:request, :with_plan, project: @project, status: "draft")

    patch update_plan_request_path(request_record), params: {
      plan_content: "## Updated Plan\n\n**Title:** Updated Title\n\n**Type:** fix"
    }, as: :json

    assert_response :success
    request_record.reload
    assert_equal "Updated Title", request_record.generated_title
  end

  test "PATCH /requests/:id/update_plan returns error for blank content" do
    request_record = create(:request, :with_plan, project: @project, status: "draft")

    patch update_plan_request_path(request_record), params: {
      plan_content: ""
    }, as: :json

    assert_response :unprocessable_entity
  end

  # ===================
  # Send to Asana Tests
  # ===================

  test "POST /requests/:id/send_to_asana pushes to Asana and updates status" do
    asana_project = create(:project, :with_asana)
    request_record = create(:request, :with_plan, project: asana_project, status: "draft")

    stub_request(:get, %r{app\.asana\.com/api/1.0/projects/.+/custom_field_settings})
      .to_return(
        status: 200,
        body: { data: [] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:post, "https://app.asana.com/api/1.0/tasks")
      .to_return(
        status: 201,
        body: { data: { gid: "asana-123", permalink_url: "https://app.asana.com/0/0/asana-123" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    post send_to_asana_request_path(request_record)

    request_record.reload
    assert_equal "sent_to_asana", request_record.status
    assert_equal "asana-123", request_record.asana_task_gid
    assert_redirected_to request_path(request_record)
  end

  test "POST /requests/:id/send_to_asana finalizes without Asana when not configured" do
    request_record = create(:request, :with_plan, project: @project, status: "draft")

    post send_to_asana_request_path(request_record)

    request_record.reload
    assert_equal "sent_to_asana", request_record.status
    assert_nil request_record.asana_task_gid
    assert_redirected_to request_path(request_record)
  end

  test "POST /requests/:id/send_to_asana rejects already-sent requests" do
    request_record = create(:request, :sent, project: @project)

    post send_to_asana_request_path(request_record)

    assert_redirected_to request_path(request_record)
    assert_match(/already been sent/, flash[:alert])
  end

  test "POST /requests/:id/send_to_asana handles Asana API errors" do
    asana_project = create(:project, :with_asana)
    request_record = create(:request, :with_plan, project: asana_project, status: "draft")

    stub_request(:get, %r{app\.asana\.com/api/1.0/projects/.+/custom_field_settings})
      .to_return(
        status: 200,
        body: { data: [] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:post, "https://app.asana.com/api/1.0/tasks")
      .to_return(
        status: 500,
        body: { errors: [{ message: "Server error" }] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    post send_to_asana_request_path(request_record)

    request_record.reload
    assert_equal "draft", request_record.status  # Remains draft on failure
    assert_redirected_to request_path(request_record)
    assert_match(/Failed to push to Asana/, flash[:alert])
  end

  # ===================
  # Comment Tests
  # ===================

  test "POST /requests/:id/comment sends message to agent" do
    request_record = create(:request, :with_plan, :with_agent, project: @project, status: "draft")

    assert_difference("Comment.count", 1) do
      post comment_request_path(request_record), params: { message: "Please add more detail" }
    end

    comment = Comment.last
    assert_equal "agent_chat", comment.comment_type
    assert_equal "user", comment.author_type
  end

  test "POST /requests/:id/comment rejects empty messages" do
    request_record = create(:request, :with_plan, :with_agent, project: @project, status: "draft")

    assert_no_difference("Comment.count") do
      post comment_request_path(request_record), params: { message: "" }
    end
  end

  # ===================
  # Poll Tests
  # ===================

  test "GET /requests/:id/poll returns agent status" do
    request_record = create(:request, :with_plan, :with_agent, project: @project, status: "draft")

    # Mock agent status check
    stub_request(:get, %r{api\.cursor\.com.*#{request_record.intake_agent_id}})
      .to_return(
        status: 200,
        body: { status: "RUNNING" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    get poll_request_path(request_record), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "processing", json["status"]
  end

  test "GET /requests/:id/poll returns no_agent when no agent" do
    request_record = create(:request, :with_plan, project: @project, status: "draft")

    get poll_request_path(request_record), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "no_agent", json["status"]
  end
end
