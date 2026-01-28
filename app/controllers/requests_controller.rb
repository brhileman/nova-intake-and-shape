# frozen_string_literal: true

class RequestsController < ApplicationController
  before_action :set_request, only: [ :show, :poll, :approve, :comment ]
  before_action :require_project, only: [ :index, :new, :create ]

  # GET /requests
  def index
    @requests = current_project.requests.order(created_at: :desc)
  end

  # GET /requests/:id
  def show
    @conversation = fetch_conversation
    @comments = @request.comments.where(phase: @request.current_phase).order(:created_at)
  end

  # GET /requests/new
  def new
    @request = current_project.requests.build
  end

  # POST /requests
  def create
    @request = current_project.requests.build(request_params)

    if @request.save
      # Auto-launch intake agent (same as CLI)
      @request.start_intake!
      agent = Agents::IntakeAgent.new(@request)
      agent.launch

      redirect_to @request, notice: "Request created. Intake agent launched."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # POST /requests/:id/approve
  def approve
    notice_message = nil

    case @request.status
    when "intake_in_progress"
      @request.complete_intake!
      notice_message = "Intake marked complete."

    when "planning_in_progress"
      @request.complete_planning!
      notice_message = "Planning marked complete."

    when "execution_in_progress"
      @request.complete_execution!
      notice_message = "Execution marked complete."

    when "intake_review"
      save_brief_from_conversation
      @request.approve_intake!
      @request.start_planning!
      # Use followup() to continue with the same agent instead of launching a new one
      agent = Agents::PlanningAgent.new(@request)
      agent.followup(agent.build_planning_transition_prompt)
      notice_message = "Intake approved. Planning phase started."

    when "planning_review"
      save_plan_from_conversation
      @request.approve_plan!
      @request.start_execution!
      # Use followup() to continue with the same agent instead of launching a new one
      agent = Agents::ExecutionAgent.new(@request)
      agent.followup(agent.build_execution_transition_prompt)
      notice_message = "Plan approved. Execution phase started."

    when "execution_review"
      save_execution_from_agent
      @request.approve_execution!
      notice_message = "Execution approved. Request completed!"

    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to @request, alert: "Cannot approve from status: #{@request.status}" }
      end
      return
    end

    @conversation = fetch_conversation

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("chat_thread_#{@request.id}", partial: "chat_thread", locals: { request: @request, conversation: @conversation }),
          turbo_stream.update("agent_status_#{@request.id}", partial: "agent_status", locals: { request: @request }),
          turbo_stream.update("phase_stepper_#{@request.id}", partial: "phase_stepper", locals: { request: @request }),
          turbo_stream.update("artifacts_#{@request.id}", partial: "artifacts_stack", locals: { request: @request }),
          turbo_stream.update("project_overview_#{@request.id}", partial: "project_overview", locals: { request: @request }),
          turbo_stream.update("pr_review_link_#{@request.id}", partial: "pr_review_link", locals: { request: @request }),
          turbo_stream.replace("request_status_value_#{@request.id}", html: "<div id='request_status_value_#{@request.id}' data-status='#{@request.status}' class='hidden'></div>".html_safe)
        ]
      end
      format.html { redirect_to @request, notice: notice_message }
    end
  end

  # POST /requests/:id/comment
  def comment
    message = params[:message]

    # Save comment to database
    @request.comments.create!(
      author_type: "user",
      author_name: "Web User",
      content: message,
      phase: @request.current_phase
    )

    # Send to agent
    agent_class = case @request.current_phase
    when "intake" then Agents::IntakeAgent
    when "planning" then Agents::PlanningAgent
    when "execution" then Agents::ExecutionAgent
    end

    if agent_class && @request.current_agent_id
      agent = agent_class.new(@request)
      agent.followup(message)

      # Transition back to in_progress so polling resumes
      # (agent is now working on the follow-up)
      case @request.status
      when "intake_review"
        @request.revise_intake!
      when "planning_review"
        @request.revise_plan!
      when "execution_review"
        @request.revise_execution!
      end
    end

    @conversation = fetch_conversation

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("chat_thread_#{@request.id}", partial: "chat_thread", locals: { request: @request, conversation: @conversation }),
          turbo_stream.update("agent_status_#{@request.id}", partial: "agent_status", locals: { request: @request }),
          turbo_stream.replace("request_status_value_#{@request.id}", html: "<div id='request_status_value_#{@request.id}' data-status='#{@request.status}' class='hidden'></div>".html_safe)
        ]
      end
      format.html { redirect_to @request }
    end
  end

  # GET /requests/:id/poll
  # Polls for updates: checks agent status, auto-transitions when complete, returns updated UI
  def poll
    # Check if agent has finished and auto-transition
    if @request.current_agent_id && @request.status.end_with?("_in_progress")
      check_and_transition_agent_status
    end

    @conversation = fetch_conversation

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("chat_thread_#{@request.id}", partial: "chat_thread", locals: { request: @request, conversation: @conversation }),
          turbo_stream.update("agent_status_#{@request.id}", partial: "agent_status", locals: { request: @request }),
          turbo_stream.update("phase_stepper_#{@request.id}", partial: "phase_stepper", locals: { request: @request }),
          turbo_stream.update("artifacts_#{@request.id}", partial: "artifacts_stack", locals: { request: @request }),
          turbo_stream.update("project_overview_#{@request.id}", partial: "project_overview", locals: { request: @request }),
          turbo_stream.update("pr_review_link_#{@request.id}", partial: "pr_review_link", locals: { request: @request }),
          turbo_stream.replace("request_status_value_#{@request.id}", html: "<div id='request_status_value_#{@request.id}' data-status='#{@request.status}' class='hidden'></div>".html_safe)
        ]
      end
      format.html { redirect_to @request }
    end
  end

  private

  def set_request
    @request = Request.find(params[:id])
  end

  def require_project
    unless current_project
      redirect_to root_path, alert: "No project found. Please create a project first via CLI."
    end
  end

  def request_params
    params.require(:request).permit(:original_input)
  end

  def fetch_conversation
    return [] unless @request.current_agent_id

    begin
      client = CursorApi::Client.new
      conv = client.get_conversation(@request.current_agent_id)
      conv["messages"] || []
    rescue CursorApi::Client::Error
      []
    end
  end

  def check_and_transition_agent_status
    return unless @request.current_agent_id

    begin
      client = CursorApi::Client.new
      agent = client.get_agent(@request.current_agent_id)

      # Agent statuses from Cursor API: "RUNNING", "FINISHED", "ERROR", etc. (uppercase)
      if agent["status"]&.upcase == "FINISHED"
        case @request.status
        when "intake_in_progress"
          @request.complete_intake!
        when "planning_in_progress"
          @request.complete_planning!
        when "execution_in_progress"
          @request.complete_execution!
        end
        @request.reload
      end
    rescue CursorApi::Client::Error
      # Silent fail - will try again on next poll
    end
  end

  def save_brief_from_conversation
    return unless @request.current_agent_id

    begin
      client = CursorApi::Client.new
      conv = client.get_conversation(@request.current_agent_id)
      last_agent_msg = conv["messages"].reverse.find { |m| m["type"] == "assistant_message" }

      if last_agent_msg
        content = last_agent_msg["text"]
        @request.briefs.create!(content: content)

        # Extract structured data from the brief
        extracted = BriefExtractor.new(content).extract
        @request.update!(extracted)
      end
    rescue CursorApi::Client::Error
      # Silent fail - brief won't be saved
    end
  end

  def save_plan_from_conversation
    return unless @request.current_agent_id

    begin
      client = CursorApi::Client.new
      conv = client.get_conversation(@request.current_agent_id)
      last_agent_msg = conv["messages"].reverse.find { |m| m["type"] == "assistant_message" }

      if last_agent_msg
        content = last_agent_msg["text"]
        @request.plans.create!(content: content)

        # Extract structured data from the plan
        extracted = PlanExtractor.new(content).extract
        @request.update!(extracted)
      end
    rescue CursorApi::Client::Error
      # Silent fail - plan won't be saved
    end
  end

  def save_execution_from_agent
    return unless @request.current_agent_id

    begin
      client = CursorApi::Client.new
      agent = client.get_agent(@request.current_agent_id)

      pr_url = agent.dig("target", "prUrl")
      summary = agent["summary"]

      # Fallback: Try to extract PR URL from conversation messages if not in agent response
      if pr_url.blank?
        Rails.logger.info "[Nova Flow] PR URL not in agent response, attempting to extract from conversation..."
        pr_url = extract_pr_url_from_conversation(client)
      end

      # Log warning if PR URL is still missing
      if pr_url.blank?
        Rails.logger.warn "[Nova Flow] No PR URL found for request #{@request.id}. " \
                          "Checked agent.target.prUrl and conversation messages. " \
                          "This may indicate a GitHub permissions issue or the PR wasn't created."

        # Check if there's error information in the agent response
        if agent["error"].present?
          Rails.logger.error "[Nova Flow] Agent error: #{agent['error']}"
        end
      else
        Rails.logger.info "[Nova Flow] PR URL found for request #{@request.id}: #{pr_url}"
      end

      @request.create_execution!(
        pr_url: pr_url,
        summary: summary
      )
    rescue CursorApi::Client::Error => e
      Rails.logger.error "[Nova Flow] Failed to save execution details: #{e.message}"
      # Silent fail - execution details won't be saved but request can still complete
    end
  end

  # Extract PR URL from conversation messages as a fallback
  # The agent often mentions the PR URL in its final message
  def extract_pr_url_from_conversation(client)
    conv = client.get_conversation(@request.current_agent_id)
    messages = conv["messages"] || []

    # Search through messages in reverse order (most recent first)
    # Look for GitHub PR URLs in assistant messages
    messages.reverse_each do |msg|
      next unless msg["type"] == "assistant_message"

      text = msg["text"] || ""

      # Match GitHub PR URLs - supports various formats:
      # https://github.com/owner/repo/pull/123
      # https://github.com/owner/repo/pull/123/files
      # https://github.com/owner/repo/pull/123#discussion_r123456
      pr_match = text.match(%r{https://github\.com/[^/]+/[^/]+/pull/\d+})
      return pr_match[0] if pr_match
    end

    nil
  rescue CursorApi::Client::Error => e
    Rails.logger.error "[Nova Flow] Failed to fetch conversation for PR extraction: #{e.message}"
    nil
  end
end
