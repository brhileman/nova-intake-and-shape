# frozen_string_literal: true

class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :select, :context, :asana_settings]

  def show
    @requests = @project.requests
    @current_filter = params[:filter] || "all"

    case @current_filter
    when "created_by_me"
      @requests = @requests.created_by_user(current_user).recent
    else
      @requests = @requests.recent
    end

    # Set current project in session when viewing a project page
    session[:current_project_id] = @project.id
  end

  def select
    session[:current_project_id] = @project.id
    redirect_back(fallback_location: root_path, notice: "Switched to #{@project.name}")
  end

  # GET /projects/:id/context - Show context editor (via Turbo Frame)
  # POST /projects/:id/context - Save context
  def context
    if request.post?
      @project.update!(context_docs: params[:context_docs])

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("context_save_status", html: '<span class="text-emerald-400 text-sm">Saved!</span>'.html_safe),
            turbo_stream.replace("context_link", partial: "context_link", locals: { project: @project })
          ]
        end
        format.html { redirect_to @project, notice: "Project context saved." }
      end
    else
      # GET - render the editor
      render layout: false
    end
  end

  # GET /projects/:id/asana_settings - Show Asana integration settings (via Turbo Frame)
  # POST /projects/:id/asana_settings - Save Asana settings
  def asana_settings
    if request.post?
      @project.update!(
        asana_workspace_gid: params[:asana_workspace_gid],
        asana_project_gid: params[:asana_project_gid]
      )

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("asana_save_status", html: '<span class="text-emerald-400 text-sm">Saved!</span>'.html_safe),
            turbo_stream.replace("asana_status_badge", partial: "asana_status_badge", locals: { project: @project })
          ]
        end
        format.html { redirect_to @project, notice: "Asana settings saved." }
      end
    else
      # GET - render the settings editor, fetch workspaces/projects if token is available
      @workspaces = []
      @asana_projects = []

      if @project.asana_access_token.present?
        begin
          client = Asana::Client.new(access_token: @project.asana_access_token)
          @workspaces = client.list_workspaces

          if @project.asana_workspace_gid.present?
            @asana_projects = client.list_projects(workspace_gid: @project.asana_workspace_gid)
          end
        rescue Asana::Client::Error => e
          @asana_error = e.message
        end
      end

      render layout: false
    end
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end
end
