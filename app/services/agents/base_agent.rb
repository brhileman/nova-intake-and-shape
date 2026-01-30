# frozen_string_literal: true

module Agents
  class BaseAgent
    class ProjectNotConfiguredError < StandardError; end

    def initialize(request)
      @request = request
      @project = request.project
      @client = CursorApi::Client.new
    end

    # Launch a new agent for this request
    # @param images [Array<Hash>] Optional array of images with :url keys
    # @return [Hash] Agent response with id, status
    def launch(images: [])
      unless @project.environment_configured?
        raise ProjectNotConfiguredError,
          "Project '#{@project.name}' is not configured for Cloud Agents. " \
          "Run 'nova project configure #{@project.id}' after setting up .cursor/environment.json"
      end

      response = @client.create_agent(
        prompt: build_prompt,
        repo_url: @project.repo_url,
        ref: @project.default_branch || "main",
        auto_create_pr: auto_create_pr?,
        images: images
      )

      @request.update!(current_agent_id: response["id"])
      response
    end

    # Send a follow-up message to the current agent
    # @param message [String] The follow-up message
    # @param images [Array<Hash>] Optional array of images with :url keys
    # @return [Hash] Response
    def followup(message, images: [])
      raise "No agent running for this request" unless @request.current_agent_id

      @client.followup(@request.current_agent_id, prompt: message, images: images)
    end

    # Get current agent status
    # @return [Hash] Agent details
    def status
      raise "No agent running for this request" unless @request.current_agent_id

      @client.get_agent(@request.current_agent_id)
    end

    # Get conversation history
    # @return [Hash] Conversation with messages
    def conversation
      raise "No agent running for this request" unless @request.current_agent_id

      @client.get_conversation(@request.current_agent_id)
    end

    protected

    # Build the prompt for this agent type
    # Must be implemented by subclasses
    def build_prompt
      raise NotImplementedError, "Subclasses must implement #build_prompt"
    end

    # Whether this agent should auto-create PRs
    def auto_create_pr?
      false
    end

    # Get project context docs
    def project_context
      @project.context_docs.presence || "No project context provided."
    end

    # Get conversation history as formatted string
    def conversation_history
      @request.comments.order(:created_at).map do |c|
        "[#{c.author_type.upcase}] #{c.content}"
      end.join("\n\n")
    end
  end
end
