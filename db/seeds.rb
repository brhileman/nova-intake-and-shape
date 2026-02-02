# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Seed test users
puts "Seeding users..."

pm_user = User.find_or_create_by!(email: "pm@example.com") do |user|
  user.name = "PM User"
  user.role = :pm
end

designer_user = User.find_or_create_by!(email: "designer@example.com") do |user|
  user.name = "Designer User"
  user.role = :designer
end

dev_user = User.find_or_create_by!(email: "dev@example.com") do |user|
  user.name = "Dev User"
  user.role = :dev
end

puts "Created #{User.count} users"

# Seed demo projects with team assignments
puts "Seeding projects..."

Project.find_or_create_by!(repo_url: "https://github.com/LaunchPadLab/astro-dance.git") do |project|
  project.name = "Astro Dance"
  project.default_branch = "main"
end.tap do |project|
  # Assign team to project
  project.update!(pm: pm_user, designer: designer_user, dev: dev_user) if project.pm.nil?
end

Project.find_or_create_by!(repo_url: "https://github.com/LaunchPadLab/prezos.git") do |project|
  project.name = "Prezos"
  project.default_branch = "main"
end.tap do |project|
  # Assign team to project
  project.update!(pm: pm_user, designer: designer_user, dev: dev_user) if project.pm.nil?
end

puts "Created #{Project.count} projects"
