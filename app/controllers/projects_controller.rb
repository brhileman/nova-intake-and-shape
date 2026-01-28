# frozen_string_literal: true

class ProjectsController < ApplicationController
  def select
    project = Project.find(params[:id])
    session[:current_project_id] = project.id
    redirect_back(fallback_location: root_path, notice: "Switched to #{project.name}")
  end
end
