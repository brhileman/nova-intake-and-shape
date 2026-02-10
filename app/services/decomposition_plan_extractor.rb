# frozen_string_literal: true

# Extracts structured data from planning decomposition agent responses
# Parses the plan output format to extract title, summary, and individual requests
class DecompositionPlanExtractor
  # Status markers that the agent outputs
  STATUS_PATTERN = /STATUS:\s*(needs_clarification|ready)/i

  # Plan section patterns
  PLAN_TITLE_PATTERN = /\*\*Title:\*\*\s*(.+?)(?=\n)/i
  PLAN_SUMMARY_PATTERN = /\*\*Summary:\*\*\s*(.+?)(?=\n\n|\*\*Scope)/im
  PLAN_SCOPE_PATTERN = /\*\*Scope:\*\*\s*(.+?)(?=\n\n|###)/im

  # Request patterns
  REQUEST_BLOCK_PATTERN = /####\s*Request\s*\d+.*?(?=####\s*Request|\n###\s*Suggested|\z)/im
  REQUEST_PRIORITY_PATTERN = /\*\*Priority:\*\*\s*(High|Medium|Low)/i
  REQUEST_DEPENDENCIES_PATTERN = /\*\*Dependencies:\*\*\s*(.+?)(?=\n)/i
  BRIEF_SECTION_PATTERN = /##\s*Request Brief\s*\n(.*?)(?=\n---|\z)/im

  # Brief field patterns (used to parse decomposition plan agent output)
  BRIEF_TITLE_PATTERN = /\*\*Recommended Title:\*\*\s*(.+?)(?=\n)/i
  BRIEF_TYPE_PATTERN = /\*\*Type:\*\*\s*(new|update|fix|chore)/i
  BRIEF_PERSONA_PATTERN = /\*\*As a\*\*\s*(.+?)(?=\n|\*\*I want)/im
  BRIEF_ACTION_PATTERN = /\*\*I want\*\*\s*(.+?)(?=\n|\*\*So that)/im
  BRIEF_OUTCOME_PATTERN = /\*\*So that\*\*\s*(.+?)(?=\n\n|\[|\z)/im

  def initialize(content)
    @content = content || ""
  end

  # Detect the status from the agent's response
  # @return [Symbol] :needs_clarification, :ready, or :unknown
  def self.detect_status(content)
    return :unknown if content.blank?

    match = content.match(STATUS_PATTERN)
    return :unknown unless match

    match[1].downcase.to_sym
  end

  # Extract the full plan section from the response
  # @return [String, nil] The plan content or nil if not found
  def self.extract_plan_section(content)
    return nil if content.blank?

    # Look for the plan section starting with "## Plan"
    match = content.match(/##\s*Plan\s*\n(.*?)(?=\n---\s*\nSTATUS:|\z)/im)
    match&.[](0)&.strip
  end

  # Extract all structured data from the plan content
  # @return [Hash] Extracted plan metadata and requests
  def extract
    {
      title: extract_field(PLAN_TITLE_PATTERN),
      summary: extract_field(PLAN_SUMMARY_PATTERN),
      scope: extract_field(PLAN_SCOPE_PATTERN),
      requests: extract_requests
    }
  end

  # Extract individual requests from the plan
  # @return [Array<Hash>] Array of request hashes with brief data
  def extract_requests
    requests = []

    # Find all request blocks
    @content.scan(REQUEST_BLOCK_PATTERN).each_with_index do |block, index|
      request = extract_request_from_block(block, index + 1)
      requests << request if request
    end

    requests
  end

  private

  def extract_field(pattern)
    match = @content.match(pattern)
    match&.[](1)&.strip&.presence
  end

  def extract_request_from_block(block, number)
    # Extract priority
    priority_match = block.match(REQUEST_PRIORITY_PATTERN)
    priority = priority_match&.[](1)&.downcase || "medium"

    # Extract dependencies
    deps_match = block.match(REQUEST_DEPENDENCIES_PATTERN)
    dependencies = deps_match&.[](1)&.strip
    dependencies = nil if dependencies&.downcase == "none"

    # Extract the brief section
    brief_match = block.match(BRIEF_SECTION_PATTERN)
    return nil unless brief_match

    brief_content = brief_match[1]

    # Extract brief fields
    title = brief_content.match(BRIEF_TITLE_PATTERN)&.[](1)&.strip
    type_match = brief_content.match(BRIEF_TYPE_PATTERN)
    type = type_match&.[](1)&.downcase || "new_feature"
    type = "new_feature" if type == "new"

    persona = brief_content.match(BRIEF_PERSONA_PATTERN)&.[](1)&.strip
    action = brief_content.match(BRIEF_ACTION_PATTERN)&.[](1)&.strip
    outcome = brief_content.match(BRIEF_OUTCOME_PATTERN)&.[](1)&.strip

    {
      number: number,
      priority: priority,
      dependencies: dependencies,
      title: title,
      type: type,
      persona: persona,
      action: action,
      outcome: outcome,
      brief_content: brief_content.strip
    }
  end
end
