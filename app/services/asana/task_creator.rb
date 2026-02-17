# frozen_string_literal: true

module Asana
  # Maps a shaped task (from PlanExtractor output) to an Asana task.
  #
  # The task name comes from the extracted title (no type prefix).
  # The task notes (description) contain the implementation plan minus the title.
  # The "LPL Status" custom field is always set to "Shaping".
  #
  # Usage:
  #   result = Asana::TaskCreator.new(
  #     project: project,
  #     request: request,
  #     plan_content: "## Implementation Plan\n..."
  #   ).create_task
  #
  #   result[:gid]  # => "1234567890"
  #   result[:url]  # => "https://app.asana.com/0/0/1234567890"
  #
  class TaskCreator
    LPL_STATUS_FIELD_NAME = "LPL Status"
    LPL_STATUS_VALUE = "Shaping"

    def initialize(project:, request:, plan_content:)
      @project = project
      @request = request
      @plan_content = plan_content
    end

    # Create an Asana task from the shaped request
    # @return [Hash] { gid: String, url: String }
    def create_task
      client = Client.new(access_token: @project.asana_access_token)

      custom_fields = resolve_custom_fields(client)

      task_data = client.create_task(
        project_gid: @project.asana_project_gid,
        name: task_name,
        html_notes: task_html_notes,
        custom_fields: custom_fields
      )

      {
        gid: task_data["gid"],
        url: task_data["permalink_url"] || "https://app.asana.com/0/0/#{task_data["gid"]}"
      }
    rescue Client::Error => e
      Rails.logger.error "[Nova Flow] Asana task creation failed for project_gid=#{@project.asana_project_gid}, workspace_gid=#{@project.asana_workspace_gid}: #{e.message}"
      raise
    end

    private

    # The Asana task name is just the title — no type prefix.
    def task_name
      @request.generated_title.presence || @request.original_input.truncate(100)
    end

    # The Asana description is the implementation plan with the title line stripped out.
    def task_notes
      return "" if @plan_content.blank?

      # Strip the "Title: ..." line (plain text or markdown bold variants)
      @plan_content
        .gsub(/^\*{0,2}(?:Recommended\s+)?Title:?\*{0,2}\s*.+\n?/, "")
        .strip
    end

    # Convert the markdown plan content to Asana-compatible HTML.
    def task_html_notes
      MarkdownToHtml.convert(task_notes)
    end

    # Look up the "LPL Status" enum custom field on the project and return
    # a hash mapping its GID to the "Shaping" enum option GID.
    # Returns an empty hash if the field or option is not found (graceful no-op).
    def resolve_custom_fields(client)
      field_settings = client.list_custom_fields(project_gid: @project.asana_project_gid)

      lpl_status_setting = field_settings.find do |setting|
        setting.dig("custom_field", "name") == LPL_STATUS_FIELD_NAME
      end

      return {} unless lpl_status_setting

      field = lpl_status_setting["custom_field"]
      shaping_option = (field["enum_options"] || []).find { |opt| opt["name"] == LPL_STATUS_VALUE }

      return {} unless shaping_option

      { field["gid"] => shaping_option["gid"] }
    rescue Client::Error => e
      Rails.logger.warn "[Nova Flow] Could not resolve LPL Status custom field: #{e.message}"
      {}
    end
  end
end
