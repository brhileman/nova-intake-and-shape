# frozen_string_literal: true

require "thor"

class NovaCli < Thor
  def self.exit_on_failure?
    true
  end

  desc "version", "Show Nova Flow version"
  def version
    puts "Nova Flow v0.1.0"
  end

  # ===================
  # Project Commands
  # ===================

  desc "project_create NAME REPO_URL", "Create a new project"
  method_option :context, type: :string, desc: "Path to context docs file"
  method_option :branch, type: :string, default: "main", desc: "Default branch"
  def project_create(name, repo_url)
    context = options[:context] ? File.read(options[:context]) : nil
    project = Project.create!(
      name: name,
      repo_url: repo_url,
      default_branch: options[:branch],
      context_docs: context
    )
    puts "Created project: #{project.name} (ID: #{project.id})"
    puts "  Repo: #{project.repo_url}"
    puts "  Branch: #{project.default_branch}"
    puts ""
    puts "⚠ Next: Configure Cloud Agent environment in the repo, then run:"
    puts "  nova project_configure #{project.id}"
  end

  desc "project_list", "List all projects"
  def project_list
    projects = Project.all
    if projects.empty?
      puts "No projects found. Create one with: nova project_create NAME REPO_URL"
      return
    end

    projects.each do |p|
      status = p.environment_configured? ? "✓ ready" : "⚠ needs setup"
      puts "#{p.id}: #{p.name}"
      puts "   #{p.repo_url} (#{p.default_branch})"
      puts "   [#{status}]"
      puts ""
    end
  end

  desc "project_configure PROJECT_ID", "Mark project as configured for Cloud Agents"
  def project_configure(project_id)
    project = Project.find(project_id)
    project.update!(environment_configured: true)
    puts "✓ #{project.name} marked as configured."
    puts "  Agents can now be launched on this project."
  end

  desc "project_context PROJECT_ID", "Update project context docs"
  method_option :file, type: :string, required: true, desc: "Path to context docs file"
  def project_context(project_id)
    project = Project.find(project_id)
    content = File.read(options[:file])
    project.update!(context_docs: content)
    puts "✓ Updated context docs for #{project.name}"
  end

  # ===================
  # Request Commands
  # ===================

  desc "request_create PROJECT_ID INPUT", "Create a new request and launch intake"
  def request_create(project_id, input)
    project = Project.find(project_id)
    request = project.requests.create!(original_input: input)
    puts "Created request #{request.id}"
    puts "  Input: #{input.truncate(60)}"
    puts "  Status: #{request.status}"
    puts ""

    # Auto-launch intake agent
    puts "Launching intake agent..."
    request.start_intake!
    agent = Agents::IntakeAgent.new(request)
    response = agent.launch
    puts "✓ Intake agent launched (#{response['id']})"
    puts ""
    puts "Check status with: nova request_status #{request.id}"
  end

  desc "request_list PROJECT_ID", "List requests for a project"
  method_option :status, type: :string, desc: "Filter by status"
  def request_list(project_id)
    project = Project.find(project_id)
    requests = project.requests.order(created_at: :desc)
    requests = requests.where(status: options[:status]) if options[:status]

    if requests.empty?
      puts "No requests found."
      return
    end

    requests.each do |r|
      puts "#{r.id}: #{r.original_input.truncate(50)}"
      puts "   Status: #{r.status}"
      puts "   Agent: #{r.current_agent_id || 'none'}"
      puts ""
    end
  end

  desc "request_status REQUEST_ID", "Check request and agent status"
  def request_status(request_id)
    request = Request.find(request_id)
    puts "Request #{request.id}"
    puts "  Input: #{request.original_input.truncate(60)}"
    puts "  Type: #{request.request_type}" if request.request_type
    puts "  Status: #{request.status}"
    puts "  Phase: #{request.current_phase}"
    puts "  Design input needed: #{request.requires_design_input?}"
    puts ""

    if request.current_agent_id
      puts "Agent: #{request.current_agent_id}"
      begin
        client = CursorApi::Client.new
        agent = client.get_agent(request.current_agent_id)
        puts "  Status: #{agent['status']}"
        puts "  PR URL: #{agent.dig('target', 'prUrl')}" if agent.dig("target", "prUrl")
        puts "  Summary: #{agent['summary']}" if agent["summary"]
      rescue CursorApi::Client::Error => e
        puts "  Error fetching agent status: #{e.message}"
      end
    else
      puts "No agent currently running."
    end
  end

  # ===================
  # Review Commands
  # ===================

  desc "review REQUEST_ID", "Review current phase output (show conversation)"
  def review(request_id)
    request = Request.find(request_id)
    puts "Request #{request.id} - #{request.status}"
    puts "=" * 50

    unless request.current_agent_id
      puts "No agent conversation to review."
      return
    end

    begin
      client = CursorApi::Client.new
      conv = client.get_conversation(request.current_agent_id)

      puts ""
      conv["messages"].each do |msg|
        type = msg["type"] == "user_message" ? "USER" : "AGENT"
        puts "[#{type}]"
        puts msg["text"]
        puts ""
        puts "-" * 40
        puts ""
      end
    rescue CursorApi::Client::Error => e
      puts "Error fetching conversation: #{e.message}"
    end
  end

  desc "approve REQUEST_ID", "Approve current phase and advance to next"
  def approve(request_id)
    request = Request.find(request_id)

    case request.status
    when "intake_in_progress"
      # First complete intake, then approve
      request.complete_intake!
      puts "✓ Intake marked complete"
      approve(request_id) # Recurse to handle approval

    when "planning_in_progress"
      # First complete planning, then approve
      request.complete_planning!
      puts "✓ Planning marked complete"
      approve(request_id) # Recurse to handle approval

    when "execution_in_progress"
      # First complete execution, then approve
      request.complete_execution!
      puts "✓ Execution marked complete"
      approve(request_id) # Recurse to handle approval

    when "intake_review"
      # Save the brief from conversation before advancing
      save_brief_from_conversation(request)

      request.approve_intake!
      request.start_planning!
      puts "✓ Intake approved. Launching planning agent..."

      agent = Agents::PlanningAgent.new(request)
      response = agent.launch
      puts "✓ Planning agent launched (#{response['id']})"

    when "planning_review"
      # Save the plan from conversation before advancing
      save_plan_from_conversation(request)

      request.approve_plan!
      request.start_execution!
      puts "✓ Plan approved. Launching execution agent..."

      agent = Agents::ExecutionAgent.new(request)
      response = agent.launch
      puts "✓ Execution agent launched (#{response['id']})"

    when "execution_review"
      # Save execution details before completing
      save_execution_from_agent(request)

      request.approve_execution!
      puts "✓ Execution approved. Request completed!"
      puts ""
      if request.execution&.pr_url
        puts "PR URL: #{request.execution.pr_url}"
      end

    else
      puts "Cannot approve from status: #{request.status}"
      puts "Request must be in a review state (_review suffix)"
    end
  end

  desc "comment REQUEST_ID MESSAGE", "Add comment and send to agent for revision"
  def comment(request_id, message)
    request = Request.find(request_id)

    # Save comment to database
    request.comments.create!(
      author_type: "user",
      author_name: "CLI User",
      content: message,
      phase: request.current_phase
    )

    # Determine which agent class based on current phase
    agent_class = case request.current_phase
                  when "intake" then Agents::IntakeAgent
                  when "planning" then Agents::PlanningAgent
                  when "execution" then Agents::ExecutionAgent
                  else
                    puts "Cannot send comment in phase: #{request.current_phase}"
                    return
                  end

    puts "Sending comment to agent..."
    agent = agent_class.new(request)
    agent.followup(message)
    puts "✓ Comment sent to agent"
  end

  private

  def save_brief_from_conversation(request)
    return unless request.current_agent_id

    begin
      client = CursorApi::Client.new
      conv = client.get_conversation(request.current_agent_id)

      # Get the last agent message as the brief
      last_agent_msg = conv["messages"].reverse.find { |m| m["type"] == "assistant_message" }
      if last_agent_msg
        request.briefs.create!(content: last_agent_msg["text"])
        puts "✓ Brief saved (version #{request.briefs.count})"
      end
    rescue CursorApi::Client::Error => e
      puts "Warning: Could not save brief: #{e.message}"
    end
  end

  def save_plan_from_conversation(request)
    return unless request.current_agent_id

    begin
      client = CursorApi::Client.new
      conv = client.get_conversation(request.current_agent_id)

      # Get the last agent message as the plan
      last_agent_msg = conv["messages"].reverse.find { |m| m["type"] == "assistant_message" }
      if last_agent_msg
        request.plans.create!(content: last_agent_msg["text"])
        puts "✓ Plan saved (version #{request.plans.count})"
      end
    rescue CursorApi::Client::Error => e
      puts "Warning: Could not save plan: #{e.message}"
    end
  end

  def save_execution_from_agent(request)
    return unless request.current_agent_id

    begin
      client = CursorApi::Client.new
      agent = client.get_agent(request.current_agent_id)

      request.create_execution!(
        pr_url: agent.dig("target", "prUrl"),
        summary: agent["summary"]
      )
      puts "✓ Execution details saved"
    rescue CursorApi::Client::Error => e
      puts "Warning: Could not save execution details: #{e.message}"
    end
  end
end
