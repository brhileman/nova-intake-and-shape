# frozen_string_literal: true

module Asana
  # HTTP client for the Asana REST API.
  # Uses a Personal Access Token (PAT) for authentication.
  # Wraps Faraday for HTTP calls.
  #
  # Usage:
  #   client = Asana::Client.new(access_token: "your-pat")
  #   client.create_task(project_gid: "12345", name: "My Task", notes: "Details...")
  #
  class Client
    class Error < StandardError; end
    class AuthenticationError < Error; end
    class NotFoundError < Error; end
    class RateLimitError < Error; end

    BASE_URL = "https://app.asana.com/api/1.0"

    def initialize(access_token: nil)
      @access_token = access_token || ENV["ASANA_ACCESS_TOKEN"]
      raise AuthenticationError, "No Asana access token provided. Set ASANA_ACCESS_TOKEN env var." unless @access_token
    end

    # Create a task in an Asana project
    # @param project_gid [String] The Asana project GID
    # @param name [String] Task name/title
    # @param notes [String] Task description (supports rich text / markdown-like formatting)
    # @param custom_fields [Hash] Optional custom field GID => value mappings
    # @return [Hash] Created task data including "gid" and "permalink_url"
    def create_task(project_gid:, name:, notes: "", custom_fields: {})
      body = {
        data: {
          name: name,
          notes: notes,
          projects: [project_gid]
        }
      }

      # Add custom fields if provided
      if custom_fields.any?
        body[:data][:custom_fields] = custom_fields
      end

      response = post("/tasks", body)
      response["data"]
    end

    # List projects in a workspace
    # @param workspace_gid [String] The Asana workspace GID
    # @param archived [Boolean] Whether to include archived projects
    # @return [Array<Hash>] Array of project data
    def list_projects(workspace_gid:, archived: false)
      params = {
        workspace: workspace_gid,
        archived: archived,
        opt_fields: "name,color,icon,permalink_url"
      }
      response = get("/projects", params)
      response["data"] || []
    end

    # List custom fields on a project
    # @param project_gid [String] The Asana project GID
    # @return [Array<Hash>] Array of custom field data
    def list_custom_fields(project_gid:)
      response = get("/projects/#{project_gid}/custom_field_settings", {
        opt_fields: "custom_field.name,custom_field.gid,custom_field.type,custom_field.enum_options,custom_field.enum_options.name"
      })
      response["data"] || []
    end

    # List workspaces accessible to the authenticated user
    # @return [Array<Hash>] Array of workspace data
    def list_workspaces
      response = get("/workspaces", { opt_fields: "name,is_organization" })
      response["data"] || []
    end

    # Get a single task
    # @param task_gid [String] The Asana task GID
    # @return [Hash] Task data
    def get_task(task_gid:)
      response = get("/tasks/#{task_gid}", { opt_fields: "name,notes,permalink_url,completed" })
      response["data"]
    end

    private

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.response :json
        f.headers["Authorization"] = "Bearer #{@access_token}"
        f.headers["Accept"] = "application/json"
      end
    end

    def get(path, params = {})
      response = connection.get(path, params)
      handle_response(response)
    end

    def post(path, body = {})
      response = connection.post(path) do |req|
        req.body = body
      end
      handle_response(response)
    end

    def handle_response(response)
      case response.status
      when 200, 201
        response.body
      when 401
        raise AuthenticationError, "Invalid Asana access token"
      when 404
        raise NotFoundError, "Asana resource not found: #{error_message(response)}"
      when 429
        raise RateLimitError, "Asana rate limit exceeded. Please try again later."
      else
        raise Error, "Asana API error (#{response.status}): #{error_message(response)}"
      end
    end

    def error_message(response)
      body = response.body
      if body.is_a?(Hash) && body["errors"]
        body["errors"].map { |e| e["message"] }.join(", ")
      else
        body.to_s.truncate(200)
      end
    end
  end
end
