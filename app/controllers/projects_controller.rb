# frozen_string_literal: true

class ProjectsController < ApplicationController
  def show
    @project = Project.find(params[:id])
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
    project = Project.find(params[:id])
    session[:current_project_id] = project.id
    redirect_back(fallback_location: root_path, notice: "Switched to #{project.name}")
  end
end
