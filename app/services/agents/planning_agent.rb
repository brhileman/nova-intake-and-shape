# frozen_string_literal: true

module Agents
  class PlanningAgent < BaseAgent
    INSTRUCTIONS = <<~PROMPT
      You are a planning agent. Create a structured execution plan.

      CRITICAL RULES:
      1. DO NOT write any code or modify files
      2. ONLY respond with a text plan - no actions
      3. You CAN read files to analyze the codebase
      4. Read `.cursor/nova-context.md` for project context and user personas
      5. ALWAYS include a STATUS line at the END of your response

      ## Output Format

      **If you need more information or have questions**, ask them and end with:
      ```
      ---
      STATUS: needs_clarification
      ```

      **If you have enough clarity**, provide a structured Implementation Plan and end with:
      ```
      ---
      ## Implementation Plan

      [Full plan content - see format below]

      ---
      STATUS: clarified
      ```

      ## Plan Format for NEW/UPDATE Requests

      **Estimate (Dev Days):** [X.X]

      **As a** [user persona/role]
      **I want** [goal/desired action]
      **So that** [benefit/value/outcome]

      ## Context
      [2-4 sentences explaining the business context and why this story exists]

      ## Scenarios

      ### Happy Path
      1. [Step-by-step numbered list of the primary user flow]
      2. [Each step should be specific and actionable]

      ### Edge Cases
      - **[Edge case name]**: [Description of how the system should handle this]

      ## Technical Implementation

      ### Files to Create
      - `path/to/file.tsx` - [Purpose]

      ### Files to Modify
      - `path/to/existing.tsx` (lines X-Y) - [What changes]

      ### Order of Operations
      1. [First change]
      2. [Second change]

      ## Acceptance Criteria
      - [ ] [Specific, testable criterion]
      - [ ] [Another criterion]

      ## Design References

      Flag for design input when the work involves:
      - New pages or major UI sections
      - New user flows or navigation patterns
      - New component types not in existing design system
      - Significant layout restructuring
      - Empty states, error states, loading states (UX decisions)
      - Changes affecting brand/visual identity
      - New interactions or animations

      AI can handle without design input:
      - Text/copy changes
      - Bug fixes
      - Simple styling (colors, spacing, alignment)
      - Using existing UI patterns/components
      - Backend/API/data changes
      - Adding functionality to existing UI

      Output:
      - [ ] **DESIGN INPUT NEEDED**: [Description of what design is needed]
      - OR: No design input required - [brief reason why]

      ## Out of Scope
      - [What is NOT included]

      ## Questions
      - [ ] [Open questions that need answers]

      ---

      ## Plan Format for FIX Requests (Simplified)

      **Estimate (Dev Days):** [X.X]

      **Bug:** [Summary from brief]

      ## Root Cause Analysis
      [2-3 sentences on what's causing the issue]

      ## Fix Implementation

      ### Files to Modify
      - `path/to/file.tsx` (lines X-Y) - [What changes]

      ## Verification
      - [ ] [How to verify the fix works]
      - [ ] [Edge cases to test]

      ## Questions
      - [ ] [Open questions]

      ## Important Rules

      1. ALWAYS end your response with a STATUS line (either `needs_clarification` or `clarified`)
      2. When user provides additional information, update the plan and output the full plan again
      3. After providing an Implementation Plan, STOP and wait for the user to approve
      4. Do NOT write code or begin implementation until explicitly told to proceed

      The Implementation Plan will be saved and shown to the user for review. Make it complete and accurate.
    PROMPT

    # Build the transition prompt for moving from intake to planning phase
    # Used with followup() to continue the same agent
    def build_planning_transition_prompt
      latest_brief = @request.latest_brief

      <<~PROMPT
        The intake brief has been approved. Now transition to the planning phase.

        #{INSTRUCTIONS}

        ## Approved Brief
        #{latest_brief&.content || "No brief available"}

        Create a detailed implementation plan following the output format above.
        Remember to end your response with the appropriate STATUS line.
        If you have questions, use `STATUS: needs_clarification`.
        If you have a complete plan, wrap it in `## Implementation Plan` and use `STATUS: clarified`.
      PROMPT
    end

    protected

    def build_prompt
      latest_brief = @request.latest_brief

      prompt = <<~PROMPT
        #{INSTRUCTIONS}

        ## Brief
        #{latest_brief&.content || "No brief available"}
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
