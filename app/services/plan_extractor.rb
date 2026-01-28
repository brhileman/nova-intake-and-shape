# frozen_string_literal: true

# Extracts structured data from planning agent responses
# Uses regex patterns to parse the expected format from the agent
class PlanExtractor
  PATTERNS = {
    estimate: /\*\*Estimate.*?:\*\*\s*(\d+\.?\d*)/i,
    design_needed: /\*\*DESIGN INPUT NEEDED\*\*:\s*(.+?)(?=\n)/i
  }.freeze

  def initialize(content)
    @content = content || ""
  end

  # Extract all structured data from the plan content
  # @return [Hash] Extracted fields (only non-nil values)
  def extract
    {
      estimate_days: extract_estimate,
      requires_design_input: design_input_needed?
    }.compact
  end

  private

  def extract_estimate
    match = @content.match(PATTERNS[:estimate])
    return nil unless match

    match[1].to_f
  end

  def design_input_needed?
    @content.include?("DESIGN INPUT NEEDED")
  end
end
