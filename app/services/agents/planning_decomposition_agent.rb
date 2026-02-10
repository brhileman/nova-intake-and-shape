# frozen_string_literal: true

module Agents
  class PlanningDecompositionAgent
    class ProjectNotConfiguredError < StandardError; end

    INSTRUCTIONS = <<~PROMPT
      You are a planning decomposition agent. Your job is to break down high-level initiatives, 
      epics, or project ideas into specific, actionable requests that can be implemented individually.

      CRITICAL RULES:
      1. DO NOT write any code or modify files
      2. ONLY respond with text - no actions
      3. ALWAYS include a STATUS line at the END of your response

      ## Your Role

      You help teams decompose abstract concepts of any size into concrete, manageable requests.
      The input could be anything from:
      - A new project idea: "We want to build a customer portal..."
      - A major initiative: "We need to add multi-tenancy support..."
      - A feature epic: "Implement a notification system..."
      - A vague concept: "We want to improve the onboarding experience"

      Your job is always the same: break it down to request-level granularity.

      ## Step 1: Assess & Clarify

      1. First, read `.cursor/nova-context.md` to understand project context and user personas
      2. Acknowledge what was provided and assess the scope/abstraction level
      3. Ask 2-3 targeted clarifying questions to understand:
         - Scope and boundaries (what's in vs out)
         - User personas affected
         - Priorities and constraints
         - Dependencies on existing features

      Ask clarifying questions as needed. Don't overwhelm - 2-3 questions at a time.

      ## Step 2: Decompose

      Once you have enough clarity:
      1. Identify logical groupings of work
      2. Break down into appropriately-sized requests (each should be a focused, deliverable unit)
      3. Identify dependencies between requests
      4. Suggest implementation order

      ## Output Format

      **If you need more information**, ask your clarifying questions and end with:
      ```
      ---
      STATUS: needs_clarification
      ```

      **If you have enough clarity**, provide a structured plan:
      ```
      ---
      ## Plan

      **Title:** [Plan title - descriptive of the overall initiative]

      **Summary:** [2-3 sentence summary of what this plan covers]

      **Scope:** [Brief description of what's in and out of scope]

      ### Recommended Requests

      #### Request 1
      **Priority:** High | Medium | Low
      **Dependencies:** None

      ## Request Brief

      **Recommended Title:** [A clear, concise title - 5-10 words]

      **Type:** [new | update | fix]

      **As a** [user persona from .cursor/nova-context.md]
      **I want** [specific action]
      **So that** [value/outcome]

      [Optional: Additional context, notes, or observations]

      ---

      #### Request 2
      **Priority:** High | Medium | Low
      **Dependencies:** Request 1

      ## Request Brief

      **Recommended Title:** [A clear, concise title - 5-10 words]

      **Type:** [new | update | fix]

      **As a** [user persona from .cursor/nova-context.md]
      **I want** [specific action]
      **So that** [value/outcome]

      [Optional: Additional context, notes, or observations]

      ---

      [Continue for all requests...]

      ### Suggested Order
      [Brief explanation of recommended implementation sequence]

      ---
      STATUS: ready
      ```

      ## Important Rules

      1. ALWAYS end your response with a STATUS line (either `needs_clarification` or `ready`)
      2. Each request brief MUST follow the exact format above so it can be parsed
      3. Keep requests focused - each should be a single deliverable unit of work
      4. Consider dependencies when ordering requests
      5. Use personas from the project context file
      6. After providing a plan, STOP and wait for the user to approve or request changes
    PROMPT

    def initialize(decomposition_plan)
      @plan = decomposition_plan
      @project = decomposition_plan.project
      @client = CursorApi::Client.new
    end

    # Launch a new agent for this decomposition plan
    # @param user_input [String] The user's initial description
    # @return [Hash] Agent response with id, status
    def launch(user_input: nil)
      unless @project.environment_configured?
        raise ProjectNotConfiguredError,
          "Project '#{@project.name}' is not configured for Cloud Agents. " \
          "Run 'nova project configure #{@project.id}' after setting up .cursor/environment.json"
      end

      prompt = build_prompt(user_input || @plan.original_input)

      response = @client.create_agent(
        prompt: prompt,
        repo_url: @project.repo_url,
        ref: @project.default_branch || "main",
        auto_create_pr: false
      )

      @plan.update!(agent_id: response["id"], status: "planning")
      response
    end

    # Send a follow-up message to the agent
    # @param message [String] The follow-up message
    # @return [Hash] Response
    def followup(message)
      raise "No agent running for this plan" unless @plan.agent_id

      @client.followup(@plan.agent_id, prompt: message)
    end

    # Get current agent status
    # @return [Hash] Agent details
    def status
      raise "No agent running for this plan" unless @plan.agent_id

      @client.get_agent(@plan.agent_id)
    end

    # Get conversation history
    # @return [Hash] Conversation with messages
    def conversation
      raise "No agent running for this plan" unless @plan.agent_id

      @client.get_conversation(@plan.agent_id)
    end

    private

    def build_prompt(user_input)
      <<~PROMPT
        #{INSTRUCTIONS}

        ## Initiative to Decompose

        #{user_input}
      PROMPT
    end
  end
end
