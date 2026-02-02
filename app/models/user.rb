# frozen_string_literal: true

class User < ApplicationRecord
  # Roles: PM manages briefs/plans, Designer provides design guidance, Dev implements
  enum :role, { pm: 0, designer: 1, dev: 2 }

  validates :name, presence: true
  validates :email, uniqueness: true, allow_nil: true

  # Role-based approval permissions
  def can_approve_brief?
    pm?
  end

  def can_approve_plan?
    pm? || dev?
  end

  def can_approve_execution?
    dev?
  end

  # Display name with role badge text
  def display_name_with_role
    "#{name} (#{role.upcase})"
  end

  # Short role label for badges
  def role_label
    role.upcase
  end

  # Role-specific colors for UI
  def role_color
    case role
    when "pm" then "blue"
    when "designer" then "purple"
    when "dev" then "green"
    else "gray"
    end
  end
end
