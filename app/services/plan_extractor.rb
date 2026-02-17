# frozen_string_literal: true

# Extracts structured data from agent responses containing implementation plans.
# Handles all request types: new/update (user story), fix (bug summary), chore (summary).
# Uses regex patterns to parse the expected format from the agent.
class PlanExtractor
  PATTERNS = {
    estimate: /\*\*Estimate.*?:\*\*\s*(\d+\.?\d*)/i,
    design_needed: /\*\*DESIGN INPUT NEEDED\*\*:\s*(.+?)(?=\n)/i,
    type: /\*\*Type:\*\*\s*(.+?)(?=\n)/i,
    title: /\*\*(?:Recommended\s+)?Title:\*\*\s*(.+?)(?=\n)/i,
    persona: /\*\*As a\*\*\s*(.+?)(?=\n|\*\*I want)/im,
    action: /\*\*I want\*\*\s*(.+?)(?=\n|\*\*So that)/im,
    outcome: /\*\*So that\*\*\s*(.+?)(?=\n\n|\n##|\z)/im,
    bug_summary: /\*\*Bug Summary:\*\*\s*(.+?)(?=\n)/i,
    summary: /\*\*Summary:\*\*\s*(.+?)(?=\n##|\z)/im
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

  # Extract just the Implementation Plan section from the full response.
  # Strips conversational preamble (e.g. "I have complete clarity now..."),
  # STATUS markers, and trailing separators.
  # @return [String, nil] The plan content (including heading) or nil if not found
  def self.extract_plan_section(content)
    return nil if content.blank?

    # Find the start of the Implementation Plan heading
    plan_start = content.index("## Implementation Plan")
    return nil unless plan_start

    plan_text = content[plan_start..]

    # Strip STATUS markers and trailing separators
    plan_text
      .gsub(/\n---\s*\nSTATUS:\s*\w+\s*\z/i, "")
      .gsub(/\nSTATUS:\s*\w+\s*\z/i, "")
      .gsub(/\n---\s*\z/, "")
      .strip
  end

  # Extract all structured data from the plan content
  # @return [Hash] Extracted fields (only non-nil values)
  def extract
    {
      estimate_days: extract_estimate,
      request_type: extract_request_type,
      generated_title: extract_field(:title),
      user_story_persona: extract_field(:persona),
      user_story_action: extract_field(:action),
      user_story_outcome: extract_field(:outcome),
      summary: extract_summary
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

  def extract_field(key)
    match = @content.match(PATTERNS[key])
    match&.[](1)&.strip&.presence
  end

  def extract_request_type
    match = @content.match(PATTERNS[:type])
    return nil unless match

    case match[1].downcase.strip
    when "new" then "new_feature"
    when "update" then "update"
    when "fix" then "fix"
    when "chore" then "chore"
    end
  end

  # Extract summary -- used by fix (Bug Summary) and chore (Summary) requests
  def extract_summary
    # Priority 1: Bug Summary (for fix requests)
    bug = extract_field(:bug_summary)
    return bug if bug.present?

    # Priority 2: Summary (for chore requests)
    extract_field(:summary)
  end
end
