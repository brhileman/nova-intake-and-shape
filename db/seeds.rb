# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Seed demo projects
puts "Seeding projects..."

Project.find_or_create_by!(repo_url: "https://github.com/LaunchPadLab/astro-dance.git") do |project|
  project.name = "Astro Dance"
  project.default_branch = "main"
end

Project.find_or_create_by!(repo_url: "https://github.com/LaunchPadLab/prezos.git") do |project|
  project.name = "Prezos"
  project.default_branch = "main"
end

puts "Created #{Project.count} projects"
