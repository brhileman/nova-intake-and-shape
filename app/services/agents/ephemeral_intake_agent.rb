# frozen_string_literal: true

module Agents
  # Ephemeral intake agent - works before a Request record is created.
  # Used during the intake flow to process the initial request and
  # potentially ask clarifying questions before drafting a plan.
  class EphemeralIntakeAgent
    class ProjectNotConfiguredError < StandardError; end

    attr_reader :agent_id

    INSTRUCTIONS = IntakeAgent::INSTRUCTIONS

    def initialize(project:, original_input:)
      @project = project
      @original_input = original_input
      @client = CursorApi::Client.new
      @agent_id = nil
    end

    # Launch the ephemeral agent
    def launch
      unless @project.environment_configured?
        raise ProjectNotConfiguredError,
          "Project '#{@project.name}' is not configured for Cloud Agents. " \
          "Run 'nova project configure #{@project.id}' after setting up .cursor/environment.json"
      end

      response = @client.create_agent(
        prompt: build_prompt,
        repo_url: @project.repo_url,
        ref: @project.default_branch || "main",
        auto_create_pr: false  # Ephemeral agent never creates PRs
      )

      @agent_id = response["id"]
      response
    end

    # Send a follow-up message
    def followup(message)
      raise "No agent running" unless @agent_id

      @client.followup(@agent_id, prompt: message)
    end

    # Get current agent status
    def status
      raise "No agent running" unless @agent_id

      @client.get_agent(@agent_id)
    end

    # Get conversation history
    def conversation
      raise "No agent running" unless @agent_id

      @client.get_conversation(@agent_id)
    end

    private

    def build_prompt
      <<~PROMPT
        #{INSTRUCTIONS}

        ## Project Context
        #{project_context}

        ## User Request
        #{@original_input}
      PROMPT
    end

    def project_context
      @project.context_docs.presence || "No project context provided."
    end
  end
end
