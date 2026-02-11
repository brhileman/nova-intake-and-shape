# frozen_string_literal: true

module Agents
  class ExecutionAgent < BaseAgent
    INSTRUCTIONS = <<~PROMPT
      You are an execution agent. Your job is to implement the approved plan.

      Use the Project Context (provided below) to understand the product, users, and constraints.

      1. Follow the plan precisely
      2. Commit and push your changes (PR is created automatically by the platform)
      3. Provide a summary of what was done
      4. Note any issues or deviations from the plan

      IMPORTANT: Do NOT run `gh pr create` - the PR is created automatically when you push.
      You are working on a feature branch. Push to this branch and a PR will be opened against main.

      After completing the work:
      - Summarize what was implemented
      - List any files created or modified
      - Note any issues encountered
      - Confirm changes are pushed and ready for review
    PROMPT

    # Build the transition prompt for moving from planning to execution phase
    # Used with followup() to continue the same agent
    def build_execution_transition_prompt
      latest_plan = @request.latest_plan
      design_guidance = @request.design_guidance
      technical_guidance = @request.technical_guidance

      prompt = <<~PROMPT
        The plan has been approved. Now transition to the execution phase.

        #{INSTRUCTIONS}

        ## Project Context
        #{project_context}

        ## Approved Plan
        #{latest_plan&.content || "No plan available"}
      PROMPT

      # Include design guidance if provided
      if design_guidance&.provided?
        prompt += <<~PROMPT

          ## Design Guidance
          #{design_guidance.specifications.presence || "See attached design screenshots for reference."}
        PROMPT

        # Include Figma links if any
        if design_guidance.figma_links.any?
          prompt += "\n\n### Figma Links\n"
          design_guidance.figma_links.each do |link|
            prompt += "- #{link.url}"
            prompt += " - #{link.description}" if link.description.present?
            prompt += "\n"
          end
        end

        if design_guidance.images.attached?
          prompt += "\n\nDesign screenshots are attached to this message. Use them as visual reference for the UI implementation."
        end
      end

      # Include technical guidance if provided
      if technical_guidance&.provided?
        prompt += <<~PROMPT

          ## Technical Guidance
          #{technical_guidance.notes}
        PROMPT
      end

      prompt += "\n\nImplement the plan now. Commit and push your changes."
      prompt
    end

    # Get design images for the API call
    # @return [Array<Hash>] Array of image hashes with :url keys
    def design_images
      guidance = @request.design_guidance
      return [] unless guidance&.images&.attached?

      guidance.images.map do |image|
        { url: Rails.application.routes.url_helpers.rails_blob_url(image, only_path: false) }
      end
    end

    protected

    def auto_create_pr?
      true # Execution agent creates PRs
    end

    def build_prompt
      latest_plan = @request.latest_plan
      design_guidance = @request.design_guidance
      technical_guidance = @request.technical_guidance

      prompt = <<~PROMPT
        #{INSTRUCTIONS}

        ## Project Context
        #{project_context}

        ## Approved Plan
        #{latest_plan&.content || "No plan available"}
      PROMPT

      # Include design guidance if provided
      if design_guidance&.provided?
        prompt += <<~PROMPT

          ## Design Guidance
          #{design_guidance.specifications.presence || "See attached design screenshots for reference."}
        PROMPT

        # Include Figma links if any
        if design_guidance.figma_links.any?
          prompt += "\n\n### Figma Links\n"
          design_guidance.figma_links.each do |link|
            prompt += "- #{link.url}"
            prompt += " - #{link.description}" if link.description.present?
            prompt += "\n"
          end
        end
      end

      # Include technical guidance if provided
      if technical_guidance&.provided?
        prompt += <<~PROMPT

          ## Technical Guidance
          #{technical_guidance.notes}
        PROMPT
      end

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
