# frozen_string_literal: true

class RequestsController < ApplicationController
  before_action :set_request, only: [ :show, :poll, :approve, :comment, :team_comment, :update_group, :update_priority, :update_dependencies ]
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
    @comments = @request.comments.where(phase: @request.current_phase).order(:created_at)
  end

  # GET /requests/new
  def new
    @request = current_project.requests.build
  end

  # POST /requests
  def create
    @request = current_project.requests.build(request_params)
    @request.created_by = current_user

    if @request.save
      # Auto-launch intake agent
      @request.start_intake!
      agent = Agents::IntakeAgent.new(@request)
      agent.launch

      redirect_to @request, notice: "Request created. Planning agent launched."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # POST /requests/:id/approve
  def approve
    notice_message = nil

    # Check if user can approve this phase
    unless @request.can_user_approve?(current_user)
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to @request, alert: cannot_approve_message }
      end
      return
    end

    # Record the approval
    @request.record_approval(current_user)

    case @request.status
    when "plan_ready"
      if @request.all_approvals_present?
        @request.approve_plan!
        @request.start_execution!
        # Use followup() to continue with the same agent instead of launching a new one
        agent = Agents::ExecutionAgent.new(@request)
        # Include design guidance images if provided
        agent.followup(agent.build_execution_transition_prompt, images: agent.design_images)
        notice_message = "Plan approved. Execution phase started."
      else
        status = @request.plan_approval_status
        pending_roles = []
        pending_roles << "PM" unless status[:pm]
        pending_roles << "Dev" unless status[:dev]
        notice_message = "Your approval has been recorded. Waiting for: #{pending_roles.join(', ')}"
      end

    when "execution_review"
      if @request.all_approvals_present?
        save_execution_from_agent
        @request.approve_execution!
        notice_message = "Execution approved. Request completed!"
      else
        notice_message = "Your approval has been recorded. Waiting for additional approvals."
      end

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
      user: current_user,
      author_type: "user",
      author_name: current_user&.name || "Web User",
      content: message,
      phase: @request.current_phase
    )

    # Send to agent
    agent_class = case @request.current_phase
    when "intake" then Agents::IntakeAgent
    when "execution" then Agents::ExecutionAgent
    end

    if agent_class && @request.current_agent_id
      # Transition back to in_progress FIRST so polling resumes immediately,
      # even if the followup call is slow or fails
      case @request.status
      when "intake_needs_clarification"
        @request.resume_intake!
      when "plan_ready"
        @request.revise_plan!
      when "execution_review"
        @request.revise_execution!
      end

      # Send to agent (non-blocking from status perspective)
      begin
        agent = agent_class.new(@request)

        # Record message count BEFORE followup so we can detect genuinely new responses
        conv = agent.conversation
        current_count = (conv["messages"] || []).length
        @request.update_column(:agent_message_count_at_followup, current_count + 1)

        agent.followup(message)

        # The followup call is synchronous -- by the time it returns, the agent
        # may have already responded and finished. Check immediately instead of
        # waiting for the next poll cycle.
        if @request.status.end_with?("_in_progress")
          client = CursorApi::Client.new
          check_and_transition_agent_status_with_client(client)
        end
      rescue StandardError => e
        Rails.logger.error "[Nova Flow] Failed to send followup to agent: #{e.message}"
        # Revert the status transition on failure so the user can try again
        revert_status_on_followup_failure
      end
    end

    @request.reload
    @conversation = fetch_conversation

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("chat_thread_#{@request.id}", partial: "chat_thread", locals: { request: @request, conversation: @conversation }),
          turbo_stream.update("agent_status_#{@request.id}", partial: "agent_status", locals: { request: @request }),
          turbo_stream.update("phase_stepper_#{@request.id}", partial: "phase_stepper", locals: { request: @request }),
          turbo_stream.update("artifacts_#{@request.id}", partial: "artifacts_stack", locals: { request: @request }),
          turbo_stream.update("project_overview_#{@request.id}", partial: "project_overview", locals: { request: @request }),
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
        format.html { redirect_to @request, alert: "Comment cannot be blank." }
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
          turbo_stream.update("team_comments_#{@request.id}", partial: "team_comments", locals: { request: @request })
        ]
      end
      format.html { redirect_to @request }
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
    # Check if agent has finished and auto-transition
    if @request.current_agent_id && (
      @request.status.end_with?("_in_progress") ||
      @request.status == "intake_needs_clarification"
    )
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
          turbo_stream.update("team_comments_#{@request.id}", partial: "team_comments", locals: { request: @request }),
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

  def cannot_approve_message
    if !current_user
      "You must be logged in to approve."
    elsif !@request.in_review_state?
      "This request is not in a review state."
    else
      phase = @request.current_approval_phase
      if @request.user_has_approved_phase?(current_user, phase)
        "You have already approved this #{phase}."
      else
        required_role = case phase
        when "plan" then "PM or Dev"
        when "execution" then "Dev"
        end
        "Only #{required_role} can approve this phase. You are #{current_user.role.upcase}."
      end
    end
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
      check_and_transition_agent_status_with_client(client)
    rescue CursorApi::Client::Error
      # Silent fail - will try again on next poll
    end
  end

  def check_and_transition_agent_status_with_client(client)
    agent = client.get_agent(@request.current_agent_id)
    agent_status = agent["status"]&.upcase

    case @request.status
    when "intake_in_progress", "intake_needs_clarification"
      # Guard: only process if there's a genuinely new assistant message
      # This prevents re-processing stale data from a previous agent turn
      if @request.agent_message_count_at_followup.present?
        conv = client.get_conversation(@request.current_agent_id)
        current_count = (conv["messages"] || []).length
        if current_count <= @request.agent_message_count_at_followup
          return @request.reload
        end
        # New message detected -- pass the already-fetched conversation through
        if agent_status == "FINISHED" || has_status_marker?(conv)
          handle_intake_agent_finished_with_conversation(conv)
        end
      else
        if agent_status == "FINISHED"
          handle_intake_agent_finished(client)
        elsif check_for_new_agent_response?(client)
          handle_intake_agent_finished(client)
        end
      end
    when "execution_in_progress"
      if agent_status == "FINISHED"
        @request.complete_execution!
        save_execution_from_agent
      end
    end
    @request.reload
  end

  # Check if the agent has sent a new response since we last checked.
  # Returns true if the latest assistant message looks like it contains
  # a status marker (needs_clarification or clarified), indicating
  # the agent has finished its turn and is waiting for user input.
  def check_for_new_agent_response?(client)
    conv = client.get_conversation(@request.current_agent_id)
    messages = conv["messages"] || []

    # If we have a message count from a recent followup, verify the
    # conversation has actually grown before considering it a new response
    if @request.agent_message_count_at_followup.present?
      return false if messages.length <= @request.agent_message_count_at_followup
    end

    # Find the latest assistant message
    last_agent_msg = messages.reverse.find { |m| m["type"] == "assistant_message" }
    return false unless last_agent_msg

    content = last_agent_msg["text"] || ""

    # If the message contains a STATUS marker, the agent has completed its turn
    PlanExtractor.detect_status(content) != :unknown
  rescue CursorApi::Client::Error
    false
  end

  # Check if a pre-fetched conversation contains a status marker in its last assistant message
  def has_status_marker?(conv)
    messages = conv["messages"] || []
    last_agent_msg = messages.reverse.find { |m| m["type"] == "assistant_message" }
    return false unless last_agent_msg

    content = last_agent_msg["text"] || ""
    PlanExtractor.detect_status(content) != :unknown
  end

  def handle_intake_agent_finished(client)
    conv = client.get_conversation(@request.current_agent_id)
    handle_intake_agent_finished_with_conversation(conv)
  end

  # Process an intake agent response using a pre-fetched conversation.
  # This avoids redundant API calls when the conversation was already fetched
  # (e.g. during message-count checks).
  def handle_intake_agent_finished_with_conversation(conv)
    last_agent_msg = (conv["messages"] || []).reverse.find { |m| m["type"] == "assistant_message" }
    return unless last_agent_msg

    content = last_agent_msg["text"]
    detected_status = PlanExtractor.detect_status(content)

    case detected_status
    when :needs_clarification
      @request.request_clarification! if @request.may_request_clarification?
    when :clarified
      save_plan_from_content(content)
    else
      # Fallback: if no status marker, check if plan section exists
      if PlanExtractor.extract_plan_section(content).present?
        save_plan_from_content(content)
      else
        # No plan section found, treat as needs clarification
        @request.request_clarification! if @request.may_request_clarification?
      end
    end
  end

  # Extract plan content from agent response, save it, and transition to plan_ready
  def save_plan_from_content(content)
    plan_content = PlanExtractor.extract_plan_section(content) || content

    # Avoid creating duplicate plans with the same content
    existing = @request.latest_plan
    unless existing && existing.content == plan_content
      @request.plans.create!(content: plan_content)

      # Extract structured data
      extracted = PlanExtractor.new(plan_content).extract
      @request.update!(extracted)
    end

    # Transition to plan_ready state
    @request.clarify_intake! if @request.may_clarify_intake?
  end

  def save_execution_from_agent
    return unless @request.current_agent_id
    # Skip if execution already exists (e.g., already saved when entering execution_review)
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
        agent = client.get_agent(@request.current_agent_id)
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

  # Revert the status transition when a followup API call fails.
  # Without this, the request stays in *_in_progress but no agent is working,
  # leaving the user stuck.
  def revert_status_on_followup_failure
    case @request.status
    when "intake_in_progress"
      @request.request_clarification! if @request.may_request_clarification?
    when "execution_in_progress"
      # For execution, revert to execution_review if possible
      # (revise_execution goes from execution_review -> execution_in_progress,
      #  so the reverse would be complete_execution, but we use a direct update
      #  since AASM may not have a reverse transition defined)
      @request.update_column(:status, "execution_review") if @request.may_complete_execution? == false
    end
  rescue => e
    Rails.logger.error "[Nova Flow] Failed to revert status after followup failure: #{e.message}"
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
