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

  test "detects design input needed" do
    content = <<~CONTENT
      ## Design References

      - [ ] **DESIGN INPUT NEEDED**: New dashboard layout required
    CONTENT

    result = PlanExtractor.new(content).extract
    assert_equal true, result[:requires_design_input]
  end

  test "returns false for no design input needed" do
    content = <<~CONTENT
      ## Design References

      No design input required - using existing patterns.
    CONTENT

    result = PlanExtractor.new(content).extract
    assert_equal false, result[:requires_design_input]
  end

  test "handles missing estimate gracefully" do
    content = "Some plan content without estimate"
    result = PlanExtractor.new(content).extract
    assert_nil result[:estimate_days]
  end

  test "handles nil content gracefully" do
    result = PlanExtractor.new(nil).extract
    assert_equal false, result[:requires_design_input]
  end
end
