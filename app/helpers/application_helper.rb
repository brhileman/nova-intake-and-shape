# frozen_string_literal: true

module ApplicationHelper
  # Returns Tailwind classes for user role badges
  def user_role_badge_class(user)
    case user.role
    when "pm"
      "bg-blue-100 text-blue-800"
    when "designer"
      "bg-purple-100 text-purple-800"
    when "dev"
      "bg-green-100 text-green-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  # Returns Tailwind classes for user role badges (header variant - lighter for dark bg)
  def user_role_badge_class_light(user)
    case user.role
    when "pm"
      "bg-blue-200/20 text-blue-100"
    when "designer"
      "bg-purple-200/20 text-purple-100"
    when "dev"
      "bg-green-200/20 text-green-100"
    else
      "bg-gray-200/20 text-gray-100"
    end
  end

  # Breadcrumb helpers for hierarchical navigation

  # Breadcrumb for project page: Home > Project Name
  def breadcrumb_for_project(project)
    [
      { label: "Home", path: root_path },
      { label: project.name, path: nil }
    ]
  end

  # Breadcrumb for request page: Home > Project Name > REQ-123
  def breadcrumb_for_request(request)
    [
      { label: "Home", path: root_path },
      { label: request.project.name, path: project_path(request.project) },
      { label: "REQ-#{request.request_number}", path: nil }
    ]
  end
end
