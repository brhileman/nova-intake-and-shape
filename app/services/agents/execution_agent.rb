# frozen_string_literal: true

module Agents
  class ExecutionAgent < BaseAgent
    INSTRUCTIONS = <<~PROMPT
      You are an execution agent. Your job is to implement the approved plan.

      Read `.cursor/nova-context.md` for project context if needed.

      1. Follow the plan precisely
      2. Create a PR with your changes
      3. Provide a summary of what was done
      4. Note any issues or deviations from the plan

      After completing the work:
      - Summarize what was implemented
      - List any files created or modified
      - Note any issues encountered
      - Confirm the PR is ready for review
    PROMPT

    # Build the transition prompt for moving from planning to execution phase
    # Used with followup() to continue the same agent
    def build_execution_transition_prompt
      latest_brief = @request.latest_brief
      latest_plan = @request.latest_plan

      <<~PROMPT
        The plan has been approved. Now transition to the execution phase.

        #{INSTRUCTIONS}

        ## Approved Brief
        #{latest_brief&.content || "No brief available"}

        ## Approved Plan
        #{latest_plan&.content || "No plan available"}

        Implement the plan now. Create a PR with your changes.
      PROMPT
    end

    protected

    def auto_create_pr?
      true # Execution agent creates PRs
    end

    def build_prompt
      latest_brief = @request.latest_brief
      latest_plan = @request.latest_plan

      prompt = <<~PROMPT
        #{INSTRUCTIONS}

        ## Brief
        #{latest_brief&.content || "No brief available"}

        ## Approved Plan
        #{latest_plan&.content || "No plan available"}
      PROMPT

      if conversation_history.present?
        prompt += <<~PROMPT

          ## Conversation So Far
          #{conversation_history}
        PROMPT
      end

      prompt
    end
  end
end
