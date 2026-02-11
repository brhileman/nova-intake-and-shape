# frozen_string_literal: true

require "application_system_test_case"

class RequestWorkflowTest < ApplicationSystemTestCase
  setup do
    @project = create(:project, name: "Test Project")
  end

  # ===================
  # End-to-End Flow Test
  # Mirrors: request_create -> plan ready -> build -> execution -> completed
  # ===================

  test "complete end-to-end request workflow" do
    # Step 1: Visit requests index
    visit requests_path
    assert_selector "h1", text: "Requests"
    assert_text "Test Project"

    # Step 2: Create a request with a plan (from ephemeral intake)
    request = create(:request, :plan_ready, project: @project)
    visit request_path(request)

    # Verify status is plan_ready
    assert_equal "plan_ready", request.status

    # Step 3: Click Build to start execution
    request.start_build!
    request.update!(execution_agent_id: "test-agent-123")
    visit request_path(request)

    assert_equal "execution_in_progress", request.reload.status

    # Step 4: Complete the build
    request.complete_build!
    request.create_execution!(pr_url: "https://github.com/test/test/pull/1", summary: "Test PR")
    visit request_path(request)

    assert_equal "completed", request.reload.status
  end

  # ===================
  # Individual Phase Tests
  # ===================

  test "plan ready phase shows plan editor" do
    request = create(:request, :plan_ready, project: @project)

    visit request_path(request)

    # Should show plan content area
    assert_selector "[data-controller='plan-editor']", visible: :all
  end

  test "execution phase shows in progress status" do
    request = create(:request, :execution_in_progress, project: @project)

    visit request_path(request)

    assert_text "Execution"
  end

  test "completed request shows completion status" do
    request = create(:request, :completed, project: @project)

    visit request_path(request)

    assert_text "Completed"
  end

  # ===================
  # Comment/Followup Tests
  # ===================

  test "send comment during planning" do
    request = create(:request, :plan_ready, project: @project)
    request.update!(planning_agent_id: "test-agent-123")

    visit request_path(request)

    # Look for message input area
    assert_selector "textarea", visible: :all
  end

  # ===================
  # UI State Tests
  # ===================

  test "request list shows correct status badges" do
    create(:request, :plan_ready, project: @project, original_input: "Feature A")
    create(:request, :execution_in_progress, project: @project, original_input: "Feature B")
    create(:request, :completed, project: @project, original_input: "Feature C")

    visit requests_path

    assert_text "Planning"
    assert_text "Execution"
    assert_text "Completed"
  end

  test "design input flag is displayed" do
    request = create(:request, :plan_ready, :with_design_input, project: @project)

    visit request_path(request)

    assert_text "Design Input Needed"
  end

  test "phase stepper shows correct progress" do
    # Planning phase
    request = create(:request, :plan_ready, project: @project)
    visit request_path(request)
    assert_text "Planning"

    # Execution phase
    request.start_build!
    visit request_path(request)
    assert_text "Execution"
  end

  # ===================
  # Empty State Tests
  # ===================

  test "empty requests list shows call to action" do
    visit requests_path

    assert_text "No requests"
    assert_text "Get started by creating a new request"
    assert_selector "a", text: "New Request"
  end

  test "redirects to root if no project exists" do
    Project.destroy_all

    visit requests_path

    assert_text "No project found"
  end
end
