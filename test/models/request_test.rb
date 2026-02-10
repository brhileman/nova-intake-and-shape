# frozen_string_literal: true

require "test_helper"

class RequestTest < ActiveSupport::TestCase
  # ===================
  # Validation Tests
  # ===================

  test "requires original_input" do
    request = build(:request, original_input: nil)
    assert_not request.valid?
    assert_includes request.errors[:original_input], "can't be blank"
  end

  test "requires project" do
    request = build(:request, project: nil)
    assert_not request.valid?
  end

  # ===================
  # State Machine Tests
  # ===================

  test "initial state is intake_pending" do
    request = create(:request)
    assert_equal "intake_pending", request.status
  end

  test "start_intake transitions from intake_pending to intake_in_progress" do
    request = create(:request)
    request.start_intake!
    assert_equal "intake_in_progress", request.status
  end

  test "request_clarification transitions from intake_in_progress to intake_needs_clarification" do
    request = create(:request, :intake_in_progress)
    request.request_clarification!
    assert_equal "intake_needs_clarification", request.status
  end

  test "clarify_intake transitions from intake_in_progress to plan_ready" do
    request = create(:request, :intake_in_progress)
    request.clarify_intake!
    assert_equal "plan_ready", request.status
  end

  test "clarify_intake transitions from intake_needs_clarification to plan_ready" do
    request = create(:request, :intake_needs_clarification)
    request.clarify_intake!
    assert_equal "plan_ready", request.status
  end

  test "full workflow state transitions" do
    request = create(:request)

    # Intake -> Plan Ready
    request.start_intake!
    assert_equal "intake_in_progress", request.status

    request.clarify_intake!
    assert_equal "plan_ready", request.status

    # Plan Approved -> Execution
    request.approve_plan!
    assert_equal "execution_pending", request.status

    request.start_execution!
    assert_equal "execution_in_progress", request.status

    request.complete_execution!
    assert_equal "execution_review", request.status

    request.approve_execution!
    assert_equal "completed", request.status
  end

  test "revise_plan sends back to intake_in_progress" do
    request = create(:request, :plan_ready)
    request.revise_plan!
    assert_equal "intake_in_progress", request.status
  end

  # ===================
  # Helper Method Tests
  # ===================

  test "current_phase returns intake for intake states" do
    request = create(:request, :intake_in_progress)
    assert_equal "intake", request.current_phase
  end

  test "current_phase returns intake for plan_ready" do
    request = create(:request, :plan_ready)
    assert_equal "intake", request.current_phase
  end

  test "current_phase returns execution for execution states" do
    request = create(:request, :execution_in_progress)
    assert_equal "execution", request.current_phase
  end

  test "latest_plan returns most recent plan" do
    request = create(:request)
    create(:plan, request: request, version: 1, content: "First")
    create(:plan, request: request, version: 2, content: "Second")

    assert_equal "Second", request.latest_plan.content
  end

  # ===================
  # Request Type Tests
  # ===================

  test "request_type enum works correctly" do
    request = create(:request)

    request.request_type_new_feature!
    assert request.request_type_new_feature?

    request.request_type_update!
    assert request.request_type_update?

    request.request_type_fix!
    assert request.request_type_fix?

    request.request_type_chore!
    assert request.request_type_chore?
  end

  # ===================
  # Association Tests
  # ===================

  test "has_many plans" do
    request = create(:request)
    create_list(:plan, 2, request: request)

    assert_equal 2, request.plans.count
  end

  test "has_one execution" do
    request = create(:request)
    create(:execution, request: request)

    assert_not_nil request.execution
  end

  test "has_many comments" do
    request = create(:request)
    create_list(:comment, 3, request: request)

    assert_equal 3, request.comments.count
  end

  test "destroying request destroys associated records" do
    request = create(:request, :completed)

    assert_difference [ "Plan.count", "Execution.count" ], -1 do
      request.destroy
    end
  end
end
