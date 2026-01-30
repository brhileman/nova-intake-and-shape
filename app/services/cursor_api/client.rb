# frozen_string_literal: true

module CursorApi
  class Client
    BASE_URL = "https://api.cursor.com/v0"

    class Error < StandardError; end
    class AuthenticationError < Error; end
    class NotFoundError < Error; end

    def initialize(api_key = ENV["CURSOR_API_KEY"])
      raise AuthenticationError, "CURSOR_API_KEY not configured" if api_key.blank?

      @conn = Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.response :json
        f.request :authorization, :basic, api_key, ""
        f.adapter Faraday.default_adapter
      end
    end

    # Launch a new cloud agent
    # @param prompt [String] The task prompt
    # @param repo_url [String] GitHub repository URL
    # @param ref [String] Git branch/ref (default: 'main')
    # @param auto_create_pr [Boolean] Whether to auto-create PR
    # @param images [Array<Hash>] Optional array of images, each with :url key
    # @return [Hash] Agent response with id, status, etc.
    def create_agent(prompt:, repo_url:, ref: "main", auto_create_pr: false, images: [])
      prompt_payload = { text: prompt }
      prompt_payload[:images] = images.map { |img| { url: img[:url] } } if images.any?

      response = @conn.post("agents", {
        prompt: prompt_payload,
        source: { repository: repo_url, ref: ref },
        target: { autoCreatePr: auto_create_pr }
      })

      handle_response(response)
    end

    # Send follow-up message to existing agent
    # @param agent_id [String] The agent ID (bc_xxx)
    # @param prompt [String] The follow-up message
    # @param images [Array<Hash>] Optional array of images, each with :url key
    # @return [Hash] Response
    def followup(agent_id, prompt:, images: [])
      prompt_payload = { text: prompt }
      prompt_payload[:images] = images.map { |img| { url: img[:url] } } if images.any?

      response = @conn.post("agents/#{agent_id}/followup", {
        prompt: prompt_payload
      })

      handle_response(response)
    end

    # Get agent status and details
    # @param agent_id [String] The agent ID
    # @return [Hash] Agent details including status, PR URL, etc.
    def get_agent(agent_id)
      response = @conn.get("agents/#{agent_id}")
      handle_response(response)
    end

    # Get conversation history for an agent
    # @param agent_id [String] The agent ID
    # @return [Hash] Conversation with messages array
    def get_conversation(agent_id)
      response = @conn.get("agents/#{agent_id}/conversation")
      handle_response(response)
    end

    # List all agents
    # @param limit [Integer] Number of agents to return (max 100)
    # @param cursor [String] Pagination cursor
    # @return [Hash] List of agents with pagination
    def list_agents(limit: 20, cursor: nil)
      params = { limit: limit }
      params[:cursor] = cursor if cursor

      response = @conn.get("agents", params)
      handle_response(response)
    end

    # Stop a running agent
    # @param agent_id [String] The agent ID
    # @return [Hash] Response
    def stop_agent(agent_id)
      response = @conn.post("agents/#{agent_id}/stop")
      handle_response(response)
    end

    private

    def handle_response(response)
      case response.status
      when 200, 201
        response.body
      when 401
        raise AuthenticationError, "Invalid API key"
      when 404
        raise NotFoundError, "Agent not found"
      else
        raise Error, "API error: #{response.status} - #{response.body}"
      end
    end
  end
end
