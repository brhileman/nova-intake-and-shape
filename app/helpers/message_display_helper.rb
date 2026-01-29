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

  # Detect if this is an intake prompt with system instructions
  def intake_prompt?(text)
    text.include?("## User Request")
  end

  # Extract just the user's request from an intake prompt
  def extract_user_request(text)
    # The user's message appears after "## User Request\n"
    if (match = text.match(/## User Request\s*\n(.+?)(?:\n## Conversation So Far|\z)/m))
      match[1].strip
    else
      # Fallback: return original if pattern doesn't match
      text
    end
  end
end
