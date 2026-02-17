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

  test "validates status inclusion" do
    request = build(:request, status: "invalid_status")
    assert_not request.valid?
    assert_includes request.errors[:status], "is not included in the list"
  end

  # ===================
  # Status Tests
  # ===================

  test "default status is draft" do
    request = create(:request)
    assert request.draft?
    assert_equal "draft", request.status
  end

  test "draft? returns true for draft status" do
    request = build(:request, status: "draft")
    assert request.draft?
  end

  test "sent_to_asana? returns true for sent status" do
    request = build(:request, status: "sent_to_asana")
    assert request.sent_to_asana?
  end

  test "agent_available? returns true when intake_agent_id present" do
    request = build(:request, intake_agent_id: "agent-123")
    assert request.agent_available?
  end

  test "agent_available? returns false when intake_agent_id absent" do
    request = build(:request, intake_agent_id: nil)
    assert_not request.agent_available?
  end

  # ===================
  # Scope Tests
  # ===================

  test "drafts scope returns only draft requests" do
    project = create(:project)
    draft = create(:request, project: project, status: "draft")
    sent = create(:request, :sent, project: project)

    assert_includes Request.drafts, draft
    assert_not_includes Request.drafts, sent
  end

  test "sent scope returns only sent requests" do
    project = create(:project)
    draft = create(:request, project: project, status: "draft")
    sent = create(:request, :sent, project: project)

    assert_includes Request.sent, sent
    assert_not_includes Request.sent, draft
  end

  # ===================
  # Display Helper Tests
  # ===================

  test "display_title prefers generated_title" do
    request = build(:request, generated_title: "My Title", original_input: "Some input")
    assert_equal "My Title", request.display_title
  end

  test "display_title falls back to truncated original_input" do
    request = build(:request, generated_title: nil, original_input: "A" * 100)
    assert_equal 60, request.display_title.length
  end

  test "numbered_title includes request number" do
    request = create(:request)
    assert_match(/REQ-\d+:/, request.numbered_title)
  end

  # ===================
  # Asana Integration Tests
  # ===================

  test "pushed_to_asana? returns true when gid present" do
    request = build(:request, asana_task_gid: "12345")
    assert request.pushed_to_asana?
  end

  test "pushed_to_asana? returns false when gid absent" do
    request = build(:request, asana_task_gid: nil)
    assert_not request.pushed_to_asana?
  end

  test "asana_url returns task url when present" do
    request = build(:request, asana_task_url: "https://app.asana.com/0/0/12345")
    assert_equal "https://app.asana.com/0/0/12345", request.asana_url
  end

  test "asana_url constructs url from gid when url not stored" do
    request = build(:request, asana_task_gid: "12345", asana_task_url: nil)
    assert_equal "https://app.asana.com/0/0/12345", request.asana_url
  end

  test "asana_url returns nil when no gid" do
    request = build(:request, asana_task_gid: nil, asana_task_url: nil)
    assert_nil request.asana_url
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

  test "has_many comments" do
    request = create(:request)
    create_list(:comment, 3, request: request)

    assert_equal 3, request.comments.count
  end

  test "auto-assigns request_number on create" do
    project = create(:project)
    r1 = create(:request, project: project)
    r2 = create(:request, project: project)

    assert_equal 1, r1.request_number
    assert_equal 2, r2.request_number
  end
end
