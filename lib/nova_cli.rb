# frozen_string_literal: true

require "thor"

class NovaCli < Thor
  def self.exit_on_failure?
    true
  end

  desc "version", "Show Nova Flow Intake & Shape version"
  def version
    puts "Nova Flow Intake & Shape v0.1.0"
  end

  # ===================
  # Project Commands
  # ===================

  desc "project_create NAME REPO_URL", "Create a new project"
  method_option :context, type: :string, desc: "Path to context docs file"
  method_option :branch, type: :string, default: "main", desc: "Default branch"
  method_option :asana_project, type: :string, desc: "Asana project GID"
  method_option :asana_workspace, type: :string, desc: "Asana workspace GID"
  def project_create(name, repo_url)
    context = options[:context] ? File.read(options[:context]) : nil
    project = Project.create!(
      name: name,
      repo_url: repo_url,
      default_branch: options[:branch],
      context_docs: context,
      asana_project_gid: options[:asana_project],
      asana_workspace_gid: options[:asana_workspace]
    )
    puts "Created project: #{project.name} (ID: #{project.id})"
    puts "  Repo: #{project.repo_url}"
    puts "  Branch: #{project.default_branch}"
    if project.asana_configured?
      puts "  Asana Project: #{project.asana_project_gid}"
    else
      puts "  Asana: Not configured (use --asana_project and --asana_workspace, or configure in UI)"
    end
  end

  desc "project_list", "List all projects"
  def project_list
    projects = Project.all
    if projects.empty?
      puts "No projects found. Create one with: nova project_create NAME REPO_URL"
      return
    end

    projects.each do |p|
      asana_status = p.asana_configured? ? "Asana connected" : "Asana not connected"
      puts "#{p.id}: #{p.name}"
      puts "   #{p.repo_url} (#{p.default_branch})"
      puts "   [#{asana_status}]"
      puts ""
    end
  end

  desc "project_context PROJECT_ID", "Update project context docs"
  method_option :file, type: :string, required: true, desc: "Path to context docs file"
  def project_context(project_id)
    project = Project.find(project_id)
    content = File.read(options[:file])
    project.update!(context_docs: content)
    puts "Updated context docs for #{project.name}"
  end

  # ===================
  # Request Commands
  # ===================

  desc "request_list PROJECT_ID", "List shaped tasks for a project"
  def request_list(project_id)
    project = Project.find(project_id)
    requests = project.requests.order(created_at: :desc)

    if requests.empty?
      puts "No shaped tasks found."
      return
    end

    requests.each do |r|
      asana = r.pushed_to_asana? ? "Asana: #{r.asana_task_gid}" : "Local only"
      puts "REQ-#{r.request_number}: #{r.display_title}"
      puts "   Type: #{r.request_type || 'unclassified'}"
      puts "   [#{asana}]"
      puts ""
    end
  end
end
