# frozen_string_literal: true

class RequestsController < ApplicationController
  before_action :set_request, only: [ :show, :poll, :comment, :team_comment, :update_group, :update_priority, :update_dependencies, :build, :update_plan ]
  before_action :require_project, only: [ :index, :new, :create ]

  # GET /requests
  def index
    @requests = current_project.requests

    # Apply filters based on params
    case params[:filter]
    when "my_projects"
      # Requests from projects where current user is on the team
      @requests = @requests.for_team_member(current_user)
    when "needs_my_action"
      @requests = @requests.needs_action_from(current_user)
    when "in_review"
      @requests = @requests.in_review
    when "created_by_me"
      @requests = @requests.created_by_user(current_user)
    end

    # Apply status filter if specified
    if params[:status].present?
      @requests = @requests.by_phase(params[:status])
    end

    @requests = @requests.order(created_at: :desc)
    @current_filter = params[:filter] || "all"
  end

  # GET /requests/:id
  def show
    @conversation = fetch_conversation
    @comments = @request.comments.order(:created_at)
    @active_panel = params[:panel] || "plan"
  end

  # GET /requests/new
  def new
    @request = current_project.requests.build
  end

  # POST /requests
  # Called from intake page AFTER agent has drafted a plan
  def create
    @request = current_project.requests.build(request_params)
    @request.created_by = current_user
    # Request is created with plan_ready status (intake happens before creation)

    ActiveRecord::Base.transaction do
      if @request.save
        # Create the plan record if plan content was provided
        if params[:plan_content].present?
          @request.plans.create!(
            content: params[:plan_content],
            created_by: current_user
          )

          # Extract structured data from the plan
          extracted = PlanExtractor.new(params[:plan_content]).extract
          @request.update!(extracted)
        end

        respond_to do |format|
          format.html { redirect_to @request, notice: "Request created successfully." }
          format.json { render json: { success: true, redirect_url: request_path(@request) } }
        end
      else
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: { success: false, errors: @request.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[Nova Flow] Request creation failed: #{e.message}"
    respond_to do |format|
      format.html { render :new, status: :unprocessable_entity }
      format.json { render json: { success: false, errors: [e.message] }, status: :unprocessable_entity }
    end
  rescue StandardError => e
    Rails.logger.error "[Nova Flow] Unexpected error during request creation: #{e.class} - #{e.message}"
    respond_to do |format|
      format.html { redirect_to new_request_path, alert: "Failed to create request. Please try again." }
      format.json { render json: { success: false, errors: ["An unexpected error occurred. Please try again."] }, status: :internal_server_error }
    end
  end

  # POST /requests/:id/comment
  # Send a message to the plan refinement or execution agent
  def comment
    message = params[:message]

    # Save comment to database
    @request.comments.create!(
      user: current_user,
      author_type: "user",
      author_name: current_user&.name || "Web User",
      content: message,
      phase: @request.current_phase
    )

    # Determine which agent to use based on phase
    if @request.in_planning_phase?
      # Use plan refinement agent
      agent_id = @request.planning_agent_id
      if agent_id.present?
        begin
          agent = Agents::PlanRefinementAgent.new(@request)
          agent.followup(message)
        rescue StandardError => e
          Rails.logger.error "[Nova Flow] Failed to send followup to planning agent: #{e.message}"
        end
      end
    elsif (@request.execution_in_progress? || @request.completed?) && @request.execution_agent_id.present?
      # Use execution agent (during execution or for follow-up changes after completion)
      begin
        agent = Agents::ExecutionAgent.new(@request)
        agent.followup(message)
        # If completed, transition back to in_progress since agent is working again
        if @request.completed?
          @request.update!(status: "execution_in_progress")
        end
      rescue StandardError => e
        Rails.logger.error "[Nova Flow] Failed to send followup to execution agent: #{e.message}"
      end
    end

    @request.reload
    @conversation = fetch_conversation

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("chat_thread_#{@request.id}", partial: "chat_thread", locals: { request: @request, conversation: @conversation }),
          turbo_stream.update("build_log_messages_#{@request.id}", partial: "build_log_messages", locals: { request: @request, conversation: @conversation }),
          turbo_stream.replace("request_status_value_#{@request.id}", html: "<div id='request_status_value_#{@request.id}' data-status='#{@request.status}' class='hidden'></div>".html_safe)
        ]
      end
      format.html { redirect_to @request }
    end
  end

  # POST /requests/:id/team_comment
  # Add a team comment (internal discussion, outside agent context)
  def team_comment
    message = params[:message]

    if message.blank?
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to request_path(@request, panel: 'comments'), alert: "Comment cannot be blank." }
      end
      return
    end

    # Create team comment
    @request.comments.create!(
      user: current_user,
      author_type: "user",
      author_name: current_user&.name || "Team Member",
      content: message,
      comment_type: "team"
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("team_comments_list_#{@request.id}", partial: "comments_list", locals: { request: @request })
        ]
      end
      format.html { redirect_to request_path(@request, panel: 'comments') }
    end
  end

  # PATCH /requests/:id/update_group
  # Update the request's group assignment
  def update_group
    group_id = params[:request_group_id]

    if group_id.present?
      group = @request.project.request_groups.find_by(id: group_id)
      @request.update(request_group: group)
    else
      @request.update(request_group: nil)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "request_row_#{@request.id}",
          partial: "requests/request_row",
          locals: { request: @request }
        )
      end
      format.html { redirect_to @request }
      format.json { render json: @request }
    end
  end

  # PATCH /requests/:id/update_priority
  # Update the request's priority
  def update_priority
    priority = params[:priority]

    if priority.present? && Request.priorities.key?(priority)
      @request.update(priority: priority)
    else
      @request.update(priority: nil)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "request_priority_#{@request.id}",
          partial: "requests/priority_selector",
          locals: { request: @request }
        )
      end
      format.html { redirect_to @request }
      format.json { render json: @request }
    end
  end

  # PATCH /requests/:id/update_dependencies
  # Update the request's dependencies
  def update_dependencies
    @request.update(dependencies: params[:dependencies])

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "request_dependencies_#{@request.id}",
          partial: "requests/dependencies_input",
          locals: { request: @request }
        )
      end
      format.html { redirect_to @request }
      format.json { render json: @request }
    end
  end

  # PATCH /requests/reorder
  # Bulk update positions for drag-and-drop reordering
  def reorder
    request_ids = params[:request_ids] || []

    Request.transaction do
      request_ids.each_with_index do |id, index|
        Request.where(id: id, project: current_project).update_all(position: index + 1)
      end
    end

    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_to current_project }
      format.json { render json: { success: true } }
    end
  rescue StandardError => e
    respond_to do |format|
      format.turbo_stream { head :unprocessable_entity }
      format.html { redirect_to current_project, alert: "Failed to reorder requests." }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  # GET /requests/:id/poll
  # Polls for updates: checks agent status, auto-transitions when complete, returns updated UI
  def poll
    # Check if execution agent has finished and auto-transition
    if @request.execution_in_progress? && @request.execution_agent_id.present?
      check_and_transition_agent_status
    end

    @conversation = fetch_conversation

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("chat_thread_#{@request.id}", partial: "chat_thread", locals: { request: @request, conversation: @conversation }),
          turbo_stream.update("build_log_messages_#{@request.id}", partial: "build_log_messages", locals: { request: @request, conversation: @conversation }),
          turbo_stream.replace("request_status_value_#{@request.id}", html: "<div id='request_status_value_#{@request.id}' data-status='#{@request.status}' class='hidden'></div>".html_safe)
        ]
      end
      format.html { redirect_to @request }
    end
  end

  # POST /requests/:id/build
  # Starts execution - transitions to execution_in_progress and launches execution agent
  def build
    unless @request.plan_ready?
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to @request, alert: "Cannot build - request is not in planning phase." }
      end
      return
    end

    # Transition to execution
    @request.start_build!

    # Launch NEW execution agent (clean slate) with plan + design guidance + technical guidance
    agent = Agents::ExecutionAgent.new(@request)
    agent.launch(images: agent.design_images)

    # Store the execution agent ID
    @request.update!(execution_agent_id: agent.agent_id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("request_status_value_#{@request.id}", html: "<div id='request_status_value_#{@request.id}' data-status='#{@request.status}' class='hidden'></div>".html_safe)
        ]
      end
      # Redirect to the build log panel so user can see the agent working
      format.html { redirect_to request_path(@request, panel: "build"), notice: "Build started. Execution agent launched." }
    end
  end

  # PATCH /requests/:id/update_plan
  # Auto-save endpoint for plan content (called by debounced JS)
  def update_plan
    plan_content = params[:plan_content]

    if plan_content.blank?
      head :unprocessable_entity
      return
    end

    # Get existing plan or create new one
    plan = @request.latest_plan || @request.plans.build(created_by: current_user)
    
    # Update plan content
    if plan.new_record?
      plan.content = plan_content
      plan.save!
    else
      plan.update!(content: plan_content)
    end

    # Return JSON response for the JavaScript auto-save handler
    render json: { success: true, saved_at: Time.current.iso8601 }
  rescue ActiveRecord::RecordInvalid => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
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
    # Try execution agent first, then planning agent
    agent_id = @request.execution_agent_id || @request.planning_agent_id
    return [] unless agent_id

    begin
      client = CursorApi::Client.new
      conv = client.get_conversation(agent_id)
      conv["messages"] || []
    rescue CursorApi::Client::Error
      []
    end
  end

  def check_and_transition_agent_status
    return unless @request.execution_agent_id

    begin
      client = CursorApi::Client.new
      check_and_transition_agent_status_with_client(client)
    rescue CursorApi::Client::Error
      # Silent fail - will try again on next poll
    end
  end

  def check_and_transition_agent_status_with_client(client)
    agent = client.get_agent(@request.execution_agent_id)
    agent_status = agent["status"]&.upcase

    # Only handle execution phase transitions now
    if @request.execution_in_progress? && agent_status == "FINISHED"
      @request.complete_build!
      save_execution_from_agent
    end

    @request.reload
  end

  def save_execution_from_agent
    return unless @request.execution_agent_id
    # Skip if execution already exists
    return if @request.execution.present?

    begin
      client = CursorApi::Client.new

      # PR creation is async - retry a few times if prUrl isn't populated yet
      pr_url = nil
      summary = nil
      branch_name = nil
      max_retries = 4
      retry_delay = 3 # seconds

      max_retries.times do |attempt|
        agent = client.get_agent(@request.execution_agent_id)
        pr_url = agent.dig("target", "prUrl")
        summary ||= agent["summary"]
        branch_name ||= agent.dig("target", "branchName")

        if pr_url.present?
          Rails.logger.info "[Nova Flow] PR URL found on attempt #{attempt + 1}: #{pr_url}"
          break
        end

        if attempt < max_retries - 1
          Rails.logger.info "[Nova Flow] PR URL not yet available (attempt #{attempt + 1}/#{max_retries}), " \
                            "waiting #{retry_delay}s for async PR creation..."
          sleep(retry_delay)
        end
      end

      # Fallback: Try to extract PR URL from conversation messages if not in agent response
      if pr_url.blank?
        Rails.logger.info "[Nova Flow] PR URL not in agent response after retries, " \
                          "attempting to extract from conversation..."
        pr_url = extract_pr_url_from_conversation(client)
      end

      # Log warning if PR URL is still missing
      if pr_url.blank?
        Rails.logger.warn "[Nova Flow] No PR URL found for request #{@request.id}. " \
                          "Checked agent.target.prUrl (with retries) and conversation messages. " \
                          "Branch: #{branch_name || 'unknown'}. " \
                          "This may indicate a GitHub permissions issue or the PR wasn't created."
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
    conv = client.get_conversation(@request.execution_agent_id)
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
