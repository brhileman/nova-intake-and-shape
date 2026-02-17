# frozen_string_literal: true

require "test_helper"

class PlanExtractorTest < ActiveSupport::TestCase
  test "extracts estimate from plan" do
    content = <<~CONTENT
      **Estimate (Dev Days):** 2.5

      ## Context
      This is the planning content.
    CONTENT

    result = PlanExtractor.new(content).extract
    assert_equal 2.5, result[:estimate_days]
  end

  test "extracts integer estimate" do
    content = "**Estimate (Dev Days):** 3\n\nSome content"
    result = PlanExtractor.new(content).extract
    assert_equal 3.0, result[:estimate_days]
  end

  test "extracts request type" do
    content = "**Type:** new\n\nSome content"
    result = PlanExtractor.new(content).extract
    assert_equal "new_feature", result[:request_type]
  end

  test "extracts title" do
    content = "**Title:** Add Dark Mode Toggle\n\nSome content"
    result = PlanExtractor.new(content).extract
    assert_equal "Add Dark Mode Toggle", result[:generated_title]
  end

  test "extracts user story fields" do
    content = <<~CONTENT
      **As a** developer
      **I want** to toggle dark mode
      **So that** I can work in low light
    CONTENT

    result = PlanExtractor.new(content).extract
    assert_equal "developer", result[:user_story_persona]
    assert_equal "to toggle dark mode", result[:user_story_action]
    assert_equal "I can work in low light", result[:user_story_outcome]
  end

  test "handles missing estimate gracefully" do
    content = "Some plan content without estimate"
    result = PlanExtractor.new(content).extract
    assert_nil result[:estimate_days]
  end

  test "handles nil content gracefully" do
    result = PlanExtractor.new(nil).extract
    assert_empty result
  end
end
