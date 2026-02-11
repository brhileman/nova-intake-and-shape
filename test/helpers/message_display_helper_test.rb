# frozen_string_literal: true

require "test_helper"

class MessageDisplayHelperTest < ActionView::TestCase
  include MessageDisplayHelper

  test "extracts user request from intake prompt" do
    intake_prompt = <<~PROMPT
      You are an intake agent. Your job is to classify and clarify the request.

      CRITICAL RULES:
      1. DO NOT write any code
      2. ONLY respond with text

      ## User Request
      Hey there, I want to swap out the star emoji for the sunglass emoji, is that possible?
    PROMPT

    result = display_message_text(intake_prompt)

    assert_equal "Hey there, I want to swap out the star emoji for the sunglass emoji, is that possible?", result
  end

  test "extracts user request when conversation history follows" do
    intake_prompt = <<~PROMPT
      You are an intake agent.

      ## User Request
      Add a new button to the homepage

      ## Conversation So Far
      Some previous messages
    PROMPT

    result = display_message_text(intake_prompt)

    assert_equal "Add a new button to the homepage", result
  end

  test "extracts user request with project context before it" do
    # This tests the case where the full prompt is displayed
    # e.g., "Project Context Testing again ## User Request add a new emoji"
    intake_prompt = <<~PROMPT
      You are an intake agent.

      ## Project Context
      Testing again

      ## User Request
      add a new emoji
    PROMPT

    result = display_message_text(intake_prompt)

    assert_equal "add a new emoji", result
  end

  test "extracts user request with Windows line endings" do
    # Test CRLF line endings
    intake_prompt = "You are an intake agent.\r\n\r\n## User Request\r\nadd a feature\r\n"

    result = display_message_text(intake_prompt)

    assert_equal "add a feature", result
  end

  test "returns approved brief for planning transition prompt" do
    planning_transition = <<~PROMPT
      The intake brief has been approved. Now transition to the planning phase.

      You are a planning agent. Create a structured execution plan.

      ## Approved Brief
      Some brief content
    PROMPT

    result = display_message_text(planning_transition)

    assert_equal "Approved brief", result
  end

  test "returns approved plan for execution transition prompt" do
    execution_transition = <<~PROMPT
      The plan has been approved. Now transition to the execution phase.

      You are an execution agent.

      ## Approved Plan
      Some plan content
    PROMPT

    result = display_message_text(execution_transition)

    assert_equal "Approved plan", result
  end

  test "returns regular message unchanged" do
    regular_message = "Can you add some error handling to this?"

    result = display_message_text(regular_message)

    assert_equal "Can you add some error handling to this?", result
  end

  test "returns empty string for blank text" do
    assert_equal "", display_message_text(nil)
    assert_equal "", display_message_text("")
  end

  test "extracts user feedback from plan refinement prompt" do
    refinement_prompt = <<~PROMPT
      You are helping refine an implementation plan.

      ## Current Plan
      Some plan content

      ## User Feedback
      Please add error handling to step 3

      ## Project Context
      Some context
    PROMPT

    result = display_message_text(refinement_prompt)

    assert_equal "Please add error handling to step 3", result
  end
end
