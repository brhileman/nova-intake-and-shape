# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    # Sort projects: those with pending tasks first, then alphabetically
    @projects = Project.all.order(:name).sort_by do |project|
      pending_count = current_user ? project.requests.needs_action_from(current_user).count : 0
      [pending_count > 0 ? 0 : 1, project.name.downcase]
    end

    @requests = Request.needs_action_from(current_user)
                       .includes(:project)
                       .order(created_at: :desc)
  end
end
