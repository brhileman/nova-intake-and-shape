# frozen_string_literal: true

# Extracts structured data from intake agent responses
# Uses regex patterns to parse the expected format from the agent
class BriefExtractor
  PATTERNS = {
    type: /\*\*Type:\*\*\s*(new|update|fix)/i,
    persona: /\*\*As a\*\*\s*(.+?)(?=\n|\*\*I want)/im,
    action: /\*\*I want\*\*\s*(.+?)(?=\n|\*\*So that)/im,
    outcome: /\*\*So that\*\*\s*(.+?)(?=\n\n|\z)/im,
    bug_summary: /\*\*Bug Summary:\*\*\s*(.+?)(?=\n)/i,
    recommended_title: /\*\*Recommended Title:\*\*\s*(.+?)(?=\n)/i
  }.freeze

  # Status markers that the agent outputs
  STATUS_PATTERN = /STATUS:\s*(needs_clarification|clarified)/i
  # Extract the Request Brief section
  BRIEF_SECTION_PATTERN = /## Request Brief\s*\n(.*?)(?=\n---\s*\nSTATUS:|\z)/im

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

  # Extract just the Request Brief section from the full response
  # @return [String, nil] The brief content or nil if not found
  def self.extract_brief_section(content)
    return nil if content.blank?

    match = content.match(BRIEF_SECTION_PATTERN)
    match&.[](1)&.strip
  end

  # Extract all structured data from the brief content
  # @return [Hash] Extracted fields (only non-nil values)
  def extract
    {
      request_type: extract_request_type,
      user_story_persona: extract_field(:persona),
      user_story_action: extract_field(:action),
      user_story_outcome: extract_field(:outcome),
      bug_summary: extract_field(:bug_summary),
      generated_title: generate_title
    }.compact
  end

  private

  def extract_field(key)
    match = @content.match(PATTERNS[key])
    match&.[](1)&.strip&.presence
  end

  def extract_request_type
    match = @content.match(PATTERNS[:type])
    return nil unless match

    type_value = match[1].downcase
    case type_value
    when "new" then "new_feature"
    when "update" then "update"
    when "fix" then "fix"
    end
  end

  def generate_title
    # Priority 1: Use the agent's recommended title if provided
    recommended = extract_field(:recommended_title)
    return summarize_text(recommended, 80) if recommended.present?

    # Priority 2: Generate from action (for new/update requests)
    action = extract_field(:action)
    return summarize_text(action, 60) if action.present?

    # Priority 3: Generate from bug summary (for fix requests)
    bug = extract_field(:bug_summary)
    return "Fix: #{summarize_text(bug, 50)}" if bug.present?

    nil
  end

  def summarize_text(text, max_length)
    return nil if text.blank?
    text.truncate(max_length, separator: " ")
  end
end
