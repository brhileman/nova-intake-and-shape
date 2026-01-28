# frozen_string_literal: true

require "test_helper"

class BriefExtractorTest < ActiveSupport::TestCase
  test "extracts type from well-formatted response" do
    content = "**Type:** new\n\n**As a** customer..."
    result = BriefExtractor.new(content).extract
    assert_equal "new_feature", result[:request_type]
  end

  test "extracts update type" do
    content = "**Type:** update\n\n**As a** user..."
    result = BriefExtractor.new(content).extract
    assert_equal "update", result[:request_type]
  end

  test "extracts fix type" do
    content = "**Type:** fix\n\n**Bug Summary:** Something is broken"
    result = BriefExtractor.new(content).extract
    assert_equal "fix", result[:request_type]
  end

  test "handles missing fields gracefully" do
    content = "Some response without expected format"
    result = BriefExtractor.new(content).extract
    assert_nil result[:request_type]
    assert_nil result[:user_story_persona]
    assert_nil result[:user_story_action]
    assert_nil result[:user_story_outcome]
  end

  test "extracts user story components" do
    content = <<~CONTENT
      **Type:** new

      **As a** site visitor
      **I want** to see my status displayed
      **So that** I know the system is working properly

      Additional notes here.
    CONTENT

    result = BriefExtractor.new(content).extract
    assert_equal "site visitor", result[:user_story_persona]
    assert_equal "to see my status displayed", result[:user_story_action]
    assert_equal "I know the system is working properly", result[:user_story_outcome]
  end

  test "extracts bug summary for fix requests" do
    content = <<~CONTENT
      **Type:** fix

      **Bug Summary:** Login button is not responding to clicks
      **Expected:** Button should submit the form
      **Actual:** Nothing happens when clicked
    CONTENT

    result = BriefExtractor.new(content).extract
    assert_equal "fix", result[:request_type]
    assert_equal "Login button is not responding to clicks", result[:bug_summary]
  end

  test "generates title from action" do
    content = <<~CONTENT
      **Type:** new

      **As a** user
      **I want** to export my data as CSV
      **So that** I can analyze it in spreadsheets
    CONTENT

    result = BriefExtractor.new(content).extract
    assert_equal "to export my data as CSV", result[:generated_title]
  end

  test "generates title from bug summary for fix requests" do
    content = <<~CONTENT
      **Type:** fix

      **Bug Summary:** Images not loading on mobile devices
    CONTENT

    result = BriefExtractor.new(content).extract
    assert_match(/Fix:.*Images not loading/, result[:generated_title])
  end

  test "handles nil content gracefully" do
    result = BriefExtractor.new(nil).extract
    assert_empty result
  end

  test "handles empty content gracefully" do
    result = BriefExtractor.new("").extract
    assert_empty result
  end
end
