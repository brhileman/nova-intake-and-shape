# frozen_string_literal: true

# Extracts structured data from planning agent responses
# Uses regex patterns to parse the expected format from the agent
class PlanExtractor
  PATTERNS = {
    estimate: /\*\*Estimate.*?:\*\*\s*(\d+\.?\d*)/i,
    design_needed: /\*\*DESIGN INPUT NEEDED\*\*:\s*(.+?)(?=\n)/i
  }.freeze

  # Status markers that the agent outputs
  STATUS_PATTERN = /STATUS:\s*(needs_clarification|clarified)/i
  # Extract the Implementation Plan section
  PLAN_SECTION_PATTERN = /## Implementation Plan\s*\n(.*?)(?=\n---\s*\nSTATUS:|\z)/im

  def initialize(content)
    @content = content || ""
  end

  # Detect the status from the agent's response
  # @return [Symbol] :needs_clarification, :clarified, or :unknown
  def self.detect_status(content)
    return :unknown if content.blank?

    match = content.match(STATUS_PATTERN)
    return :unknown unless match

    match[1].downcase.to_sym
  end

  # Extract just the Implementation Plan section from the full response
  # @return [String, nil] The plan content or nil if not found
  def self.extract_plan_section(content)
    return nil if content.blank?

    match = content.match(PLAN_SECTION_PATTERN)
    match&.[](1)&.strip
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
