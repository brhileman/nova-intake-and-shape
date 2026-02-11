# frozen_string_literal: true

module Agents
  # Agent for refining plans on the request detail page.
  # This agent helps users iterate on and improve their implementation plan
  # through conversation.
  class PlanRefinementAgent < BaseAgent
    INSTRUCTIONS = <<~PROMPT
      You are helping refine an implementation plan. The current plan is provided below.
      
      Help the user improve, clarify, or expand the plan based on their feedback.
      When you update the plan, output the complete revised plan in a clearly marked section.
      
      Be specific and actionable in your suggestions. Focus on:
      - Breaking down complex tasks into smaller, manageable steps
      - Identifying potential edge cases or challenges
      - Suggesting implementation approaches and patterns
      - Clarifying ambiguous requirements
    PROMPT

    # Launch a new planning refinement agent
    def launch(images: [])
      unless @project.environment_configured?
        raise ProjectNotConfiguredError,
          "Project '#{@project.name}' is not configured for Cloud Agents."
      end

      response = @client.create_agent(
        prompt: build_prompt,
        repo_url: @project.repo_url,
        ref: @project.default_branch || "main",
        auto_create_pr: false,  # Planning agent never creates PRs
        images: images
      )

      # Store the planning agent ID (separate from execution agent)
      @request.update!(planning_agent_id: response["id"])
      response
    end

    # Send a follow-up message to the planning agent
    def followup(message, images: [])
      raise "No planning agent running for this request" unless @request.planning_agent_id

      @client.followup(@request.planning_agent_id, prompt: message, images: images)
    end

    # Get current agent status
    def status
      raise "No planning agent running for this request" unless @request.planning_agent_id

      @client.get_agent(@request.planning_agent_id)
    end

    # Get conversation history
    def conversation
      raise "No planning agent running for this request" unless @request.planning_agent_id

      @client.get_conversation(@request.planning_agent_id)
    end

    # Get the agent ID
    def agent_id
      @request.planning_agent_id
    end

    protected

    def build_prompt
      <<~PROMPT
        #{INSTRUCTIONS}
        
        ## Current Plan
        #{@request.latest_plan&.content || "No plan content yet."}
        
        ## Project Context
        #{project_context}
        
        ## Original Request
        #{@request.original_input}
      PROMPT
    end

    def auto_create_pr?
      false
    end
  end
end
