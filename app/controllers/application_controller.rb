class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # For now, use first project as the "test" project
  def current_project
    @current_project ||= Project.first
  end
  helper_method :current_project
end
