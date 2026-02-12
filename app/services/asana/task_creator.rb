# frozen_string_literal: true

module Asana
  # Maps a shaped task (from PlanExtractor output) to an Asana task.
  #
  # The task name comes from the extracted title.
  # The task notes (description) contain the full shaped plan markdown.
  # Custom fields are mapped if the Asana project has them configured.
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
    def initialize(project:, request:, plan_content:)
      @project = project
      @request = request
      @plan_content = plan_content
    end

    # Create an Asana task from the shaped request
    # @return [Hash] { gid: String, url: String }
    def create_task
      client = Client.new(access_token: @project.asana_access_token)

      task_data = client.create_task(
        project_gid: @project.asana_project_gid,
        name: task_name,
        notes: task_notes
      )

      {
        gid: task_data["gid"],
        url: task_data["permalink_url"] || "https://app.asana.com/0/0/#{task_data["gid"]}"
      }
    end

    private

    # Build the task name from the extracted title or original input
    def task_name
      title = @request.generated_title.presence || @request.original_input.truncate(100)

      # Prefix with type if available
      type_prefix = case @request.request_type
      when "new_feature" then "[New] "
      when "update" then "[Update] "
      when "fix" then "[Fix] "
      when "chore" then "[Chore] "
      else ""
      end

      "#{type_prefix}#{title}"
    end

    # Build the task notes (description) with structured information + full plan
    def task_notes
      sections = []

      # Add user story if present
      if @request.user_story_persona.present?
        sections << "USER STORY"
        sections << "As a #{@request.user_story_persona}"
        sections << "I want #{@request.user_story_action}" if @request.user_story_action.present?
        sections << "So that #{@request.user_story_outcome}" if @request.user_story_outcome.present?
        sections << ""
      end

      # Add summary for fix/chore requests
      if @request.summary.present?
        sections << "SUMMARY"
        sections << @request.summary
        sections << ""
      end

      # Add metadata
      metadata = []
      metadata << "Type: #{@request.request_type&.humanize}" if @request.request_type.present?
      metadata << "Estimate: #{@request.estimate_days} dev days" if @request.estimate_days.present?
      metadata << "Nova Request: REQ-#{@request.request_number}" if @request.request_number.present?

      if metadata.any?
        sections << "METADATA"
        sections += metadata
        sections << ""
      end

      # Add the full shaped plan
      if @plan_content.present?
        sections << "─" * 40
        sections << "SHAPED TASK DETAILS"
        sections << "─" * 40
        sections << ""
        sections << @plan_content
      end

      # Add original request for reference
      sections << ""
      sections << "─" * 40
      sections << "ORIGINAL REQUEST"
      sections << "─" * 40
      sections << @request.original_input

      sections.join("\n")
    end
  end
end
