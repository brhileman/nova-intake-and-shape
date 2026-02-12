# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Seed test users
puts "Seeding users..."

pm_user = User.find_or_create_by!(email: "pm@example.com") do |user|
  user.name = "PM User"
  user.role = :pm
end

User.find_or_create_by!(email: "designer@example.com") do |user|
  user.name = "Designer User"
  user.role = :designer
end

User.find_or_create_by!(email: "dev@example.com") do |user|
  user.name = "Dev User"
  user.role = :dev
end

puts "Created #{User.count} users"

# Seed demo projects
puts "Seeding projects..."

Project.find_or_create_by!(repo_url: "https://github.com/LaunchPadLab/astro-dance.git") do |project|
  project.name = "Astro Dance"
  project.default_branch = "main"
  project.pm = pm_user
end

Project.find_or_create_by!(repo_url: "https://github.com/LaunchPadLab/prezos.git") do |project|
  project.name = "Prezos"
  project.default_branch = "main"
  project.pm = pm_user
end

puts "Created #{Project.count} projects"
