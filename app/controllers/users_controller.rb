# frozen_string_literal: true

class UsersController < ApplicationController
  # Switch current user (for role-based testing)
  def select
    user = User.find(params[:id])
    session[:current_user_id] = user.id
    redirect_back fallback_location: root_path, notice: "Switched to #{user.display_name_with_role}"
  end
end
