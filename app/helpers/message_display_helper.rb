# frozen_string_literal: true

module MessageDisplayHelper
  # Process a user message for display, extracting just the user's actual input
  # and replacing approval prompts with "Approved"
  # @param text [String] The full message text from the API
  # @return [String] The cleaned message for display
  def display_message_text(text)
    return "" if text.blank?

    # Check for approval prompts (planning or execution approval)
    if approval_prompt?(text)
      return approval_display_text(text)
    end

    # Check for plan refinement feedback prompt (user's feedback during planning)
    if plan_refinement_prompt?(text)
      return extract_user_feedback(text)
    end

    # Check for intake prompt (initial message with system instructions)
    if intake_prompt?(text)
      return extract_user_request(text)
    end

    # Regular message - return as-is
    text
  end

  private

  # Detect if this is an approval transition prompt
  def approval_prompt?(text)
    text.include?("has been approved. Now transition to")
  end

  # Return appropriate approval text based on which phase was approved
  def approval_display_text(text)
    if text.include?("intake brief has been approved")
      "Approved brief"
    elsif text.include?("plan has been approved")
      "Approved plan"
    else
      "Approved"
    end
  end

  # Detect if this is a plan refinement prompt with user feedback
  def plan_refinement_prompt?(text)
    text.include?("## User Feedback") || text.include?("## Original Request")
  end

  # Extract just the user's feedback from a plan refinement prompt
  def extract_user_feedback(text)
    # Look for "## User Feedback" section first
    if (match = text.match(/## User Feedback[\s\r\n]+(.+?)(?:\r?\n##|\z)/m))
      return match[1].strip
    end

    # Fallback to original text
    text
  end

  # Detect if this is an intake prompt with system instructions
  def intake_prompt?(text)
    text.include?("## User Request")
  end

  # Extract just the user's request from an intake prompt
  # Handles various line ending formats (\n, \r\n, or even missing newlines)
  def extract_user_request(text)
    # Try to extract the user's message after "## User Request"
    # Handle both \n and \r\n line endings, and cases where there might be
    # whitespace or the content starts on the same line
    if (match = text.match(/## User Request[\s\r\n]+(.+?)(?:\r?\n## Conversation So Far|\z)/m))
      match[1].strip
    elsif (match = text.match(/## User Request\s+(.+)/m))
      # Fallback: just get everything after "## User Request " (with at least one space)
      # This handles cases where content might be on the same line
      extracted = match[1]
      # Remove any trailing sections that start with ##
      extracted = extracted.split(/\r?\n##/).first if extracted.include?("##")
      extracted&.strip || text
    else
      # Last resort fallback: return original if no pattern matches
      text
    end
  end
end
