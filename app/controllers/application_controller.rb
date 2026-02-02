class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Get the current project from session, fallback to first project
  def current_project
    @current_project ||= begin
      if session[:current_project_id]
        Project.find_by(id: session[:current_project_id]) || Project.first
      else
        Project.first
      end
    end
  end
  helper_method :current_project

  # Helper to get all projects for the dropdown
  def all_projects
    @all_projects ||= Project.order(:name)
  end
  helper_method :all_projects

  # Get the current user from session, fallback to first user (PM)
  def current_user
    @current_user ||= begin
      if session[:current_user_id]
        User.find_by(id: session[:current_user_id]) || User.first
      else
        User.first
      end
    end
  end
  helper_method :current_user

  # Helper to get all users for the dropdown
  def all_users
    @all_users ||= User.order(:role, :name)
  end
  helper_method :all_users
end
