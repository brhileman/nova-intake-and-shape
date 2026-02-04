# frozen_string_literal: true

class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :select, :context]

  def show
    @requests = @project.requests

    # Apply filters based on params (same logic as RequestsController)
    case params[:filter]
    when "needs_my_action"
      @requests = @requests.needs_action_from(current_user)
    when "in_review"
      @requests = @requests.in_review
    when "created_by_me"
      @requests = @requests.created_by_user(current_user)
    end

    @requests = @requests.order(created_at: :desc)
    @current_filter = params[:filter] || "all"

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

  private

  def set_project
    @project = Project.find(params[:id])
  end
end
