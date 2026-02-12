# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @projects = Project.all.order(:name)
    @recent_requests = Request.includes(:project)
                              .order(created_at: :desc)
                              .limit(10)
  end
end
