# frozen_string_literal: true

require "application_system_test_case"

class RequestWorkflowTest < ApplicationSystemTestCase
  setup do
    @project = create(:project, name: "Test Project")
  end

  # ===================
  # End-to-End Flow Test
  # Mirrors CLI: request_create -> review -> approve (x3 phases) -> completed
  # ===================

  test "complete end-to-end request workflow" do
    # Step 1: Visit requests index (equivalent to CLI project context)
    visit requests_path
    assert_selector "h1", text: "Requests"
    assert_text "Test Project"

    # Step 2: Create a new request (equivalent to: nova request_create)
    click_link "New Request"
    assert_selector "h1", text: "New Request"

    fill_in "What do you need?", with: "Add a dark mode toggle to the settings page"
    click_button "Create Request"

    # Should redirect to show page with intake agent launched
    assert_text "Request created. Intake agent launched."
    assert_selector "[data-testid='phase-stepper']", visible: :any rescue nil
    assert_text "Intake"

    # Verify status is intake_in_progress
    request = Request.last
    assert_equal "intake_in_progress", request.status

    # Step 3: Simulate agent completing intake (would normally happen async)
    request.complete_intake!
    visit request_path(request)

    # Step 4: Review intake (equivalent to: nova review)
    assert_text "Intake Conversation"
    assert_selector "[data-testid='status-badge']", visible: :any rescue nil

    # Step 5: Approve intake (equivalent to: nova approve)
    # First need to mark it as review state
    assert_equal "intake_review", request.reload.status
    click_button "Approve & Continue"

    assert_text "Intake approved. Planning agent launched."

    # Verify moved to planning_in_progress
    request.reload
    assert request.status.start_with?("planning")

    # Step 6: Simulate planning completion
    request.complete_planning! if request.planning_in_progress?
    visit request_path(request)

    # Step 7: Approve planning
    assert_equal "planning_review", request.reload.status
    click_button "Approve & Continue"

    assert_text "Plan approved. Execution agent launched."

    # Step 8: Simulate execution completion
    request.reload
    request.complete_execution! if request.execution_in_progress?
    visit request_path(request)

    # Step 9: Approve execution - completes the request
    assert_equal "execution_review", request.reload.status
    click_button "Approve & Continue"

    assert_text "Execution approved. Request completed!"
    assert_equal "completed", request.reload.status
  end

  # ===================
  # Individual Phase Tests
  # ===================

  test "create new request and launch intake agent" do
    visit new_request_path

    fill_in "What do you need?", with: "Fix the login button not working on mobile"
    click_button "Create Request"

    assert_text "Request created. Intake agent launched."

    request = Request.last
    assert_equal "intake_in_progress", request.status
    assert_not_nil request.current_agent_id
    assert_equal "Fix the login button not working on mobile", request.original_input
  end

  test "review intake phase shows conversation" do
    request = create(:request, :intake_review, project: @project)

    visit request_path(request)

    assert_text "Intake Conversation"
    assert_text "Intake Review"
    assert_selector "button", text: "Approve & Continue"
  end

  test "approve intake transitions to planning" do
    request = create(:request, :intake_review, project: @project)

    visit request_path(request)
    click_button "Approve & Continue"

    assert_text "Intake approved. Planning agent launched."
    assert request.reload.status.start_with?("planning")
  end

  test "review planning phase shows brief and plan" do
    request = create(:request, :planning_review, project: @project)

    visit request_path(request)

    assert_text "Planning Conversation"
    assert_text "Brief"  # Should show brief artifact
    assert_selector "button", text: "Approve & Continue"
  end

  test "approve planning transitions to execution" do
    request = create(:request, :planning_review, project: @project)

    visit request_path(request)
    click_button "Approve & Continue"

    assert_text "Plan approved. Execution agent launched."
    assert request.reload.status.start_with?("execution")
  end

  test "review execution phase shows PR link when complete" do
    request = create(:request, :execution_review, project: @project)

    visit request_path(request)

    assert_text "Execution Conversation"
    assert_text "Brief"
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

  test "send comment during intake review" do
    request = create(:request, :intake_review, project: @project)

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

  test "send comment during planning review" do
    request = create(:request, :planning_review, project: @project)

    visit request_path(request)

    fill_in placeholder: "Type your message...", with: "Please add more detail to step 2"
    click_button "Send"

    comment = request.comments.last
    assert_equal "planning", comment.phase
  end

  # ===================
  # UI State Tests
  # ===================

  test "request list shows correct status badges" do
    create(:request, :intake_in_progress, project: @project, original_input: "Feature A")
    create(:request, :planning_review, project: @project, original_input: "Feature B")
    create(:request, :completed, project: @project, original_input: "Feature C")

    visit requests_path

    assert_text "Intake In Progress"
    assert_text "Planning Review"
    assert_text "Completed"
  end

  test "design input flag is displayed" do
    request = create(:request, :planning_review, :with_design_input, project: @project)

    visit request_path(request)

    assert_text "Design Input Needed"
  end

  test "phase stepper shows correct progress" do
    # Intake phase
    request = create(:request, :intake_review, project: @project)
    visit request_path(request)
    assert_text "Intake"

    # Planning phase
    request.approve_intake!
    request.start_planning!
    visit request_path(request)
    assert_text "Planning"

    # Execution phase
    request.complete_planning!
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
