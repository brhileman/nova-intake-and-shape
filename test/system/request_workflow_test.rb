# frozen_string_literal: true

require "application_system_test_case"

class RequestWorkflowTest < ApplicationSystemTestCase
  setup do
    @project = create(:project, name: "Test Project")
  end

  # ===================
  # End-to-End Flow Test
  # Mirrors: request_create -> plan ready -> approve plan -> execution -> approve -> completed
  # ===================

  test "complete end-to-end request workflow" do
    # Step 1: Visit requests index
    visit requests_path
    assert_selector "h1", text: "Requests"
    assert_text "Test Project"

    # Step 2: Create a new request
    click_link "New Request"
    assert_selector "h1", text: "New Request"

    fill_in "What do you need?", with: "Add a dark mode toggle to the settings page"
    click_button "Create Request"

    # Should redirect to show page with planning agent launched
    assert_text "Request created. Planning agent launched."

    # Verify status is intake_in_progress
    request = Request.last
    assert_equal "intake_in_progress", request.status

    # Step 3: Simulate agent completing intake with a plan
    request.clarify_intake!
    assert_equal "plan_ready", request.status
    visit request_path(request)

    # Step 4: Approve plan -> transitions to execution
    # (In reality, both PM and Dev would need to approve)
    # Simulate both approvals
    request.approve_plan!
    request.start_execution!
    visit request_path(request)

    assert_equal "execution_in_progress", request.reload.status

    # Step 5: Simulate execution completion
    request.complete_execution!
    visit request_path(request)

    # Step 6: Approve execution - completes the request
    assert_equal "execution_review", request.reload.status
    click_button "Approve & Continue"

    assert_text "Execution approved. Request completed!"
    assert_equal "completed", request.reload.status
  end

  # ===================
  # Individual Phase Tests
  # ===================

  test "create new request and launch planning agent" do
    visit new_request_path

    fill_in "What do you need?", with: "Fix the login button not working on mobile"
    click_button "Create Request"

    assert_text "Request created. Planning agent launched."

    request = Request.last
    assert_equal "intake_in_progress", request.status
    assert_not_nil request.current_agent_id
    assert_equal "Fix the login button not working on mobile", request.original_input
  end

  test "review plan ready phase shows plan" do
    request = create(:request, :plan_ready, project: @project)

    visit request_path(request)

    assert_text "Plan"
    assert_selector "button", text: "Approve"
  end

  test "review execution phase shows PR link when complete" do
    request = create(:request, :execution_review, project: @project)

    visit request_path(request)

    assert_text "Plan"
    assert_selector "button", text: "Approve & Continue"
  end

  test "approve execution completes request" do
    request = create(:request, :execution_review, project: @project)

    visit request_path(request)
    click_button "Approve & Continue"

    assert_text "Execution approved. Request completed!"
    assert_equal "completed", request.reload.status
  end

  test "completed request shows PR link" do
    request = create(:request, :completed, project: @project)

    visit request_path(request)

    assert_text "Request Completed"
    assert_text "Pull Request Created"
    assert_selector "a", text: "View PR on GitHub"
  end

  # ===================
  # Comment/Followup Tests
  # ===================

  test "send comment during intake" do
    request = create(:request, :intake_needs_clarification, project: @project)

    visit request_path(request)

    fill_in placeholder: "Type your message...", with: "Can you clarify the scope?"
    click_button "Send"

    # Comment should be saved
    assert_equal 1, request.comments.count
    comment = request.comments.last
    assert_equal "user", comment.author_type
    assert_equal "Can you clarify the scope?", comment.content
    assert_equal "intake", comment.phase
  end

  # ===================
  # UI State Tests
  # ===================

  test "request list shows correct status badges" do
    create(:request, :intake_in_progress, project: @project, original_input: "Feature A")
    create(:request, :plan_ready, project: @project, original_input: "Feature B")
    create(:request, :completed, project: @project, original_input: "Feature C")

    visit requests_path

    assert_text "Planning In Progress"
    assert_text "Plan Ready"
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
    request.approve_plan!
    request.start_execution!
    visit request_path(request)
    assert_text "Execution"
  end

  test "agent working indicator shows during in_progress states" do
    request = create(:request, :intake_in_progress, project: @project)

    visit request_path(request)

    assert_text "Agent is working"
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
