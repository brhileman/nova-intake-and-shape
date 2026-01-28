# frozen_string_literal: true

# Extracts structured data from intake agent responses
# Uses regex patterns to parse the expected format from the agent
class BriefExtractor
  PATTERNS = {
    type: /\*\*Type:\*\*\s*(new|update|fix)/i,
    persona: /\*\*As a\*\*\s*(.+?)(?=\n|\*\*I want)/im,
    action: /\*\*I want\*\*\s*(.+?)(?=\n|\*\*So that)/im,
    outcome: /\*\*So that\*\*\s*(.+?)(?=\n\n|\z)/im,
    bug_summary: /\*\*Bug Summary:\*\*\s*(.+?)(?=\n)/i
  }.freeze

  def initialize(content)
    @content = content || ""
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
    # Try to generate a title from the action or bug summary
    action = extract_field(:action)
    return summarize_text(action, 60) if action.present?

    bug = extract_field(:bug_summary)
    return "Fix: #{summarize_text(bug, 50)}" if bug.present?

    nil
  end

  def summarize_text(text, max_length)
    return nil if text.blank?
    text.truncate(max_length, separator: " ")
  end
end
