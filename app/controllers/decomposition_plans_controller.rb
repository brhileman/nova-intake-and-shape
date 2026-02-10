# frozen_string_literal: true

class DecompositionPlansController < ApplicationController
  before_action :set_project
  before_action :set_decomposition_plan, only: [:show, :followup, :poll, :approve, :cancel]

  # GET /projects/:project_id/decomposition_plans/new
  # Show the plans list (intermediary screen)
  def new
    @plans = @project.decomposition_plans.order(created_at: :desc)
    # Renders new.html.erb which shows the plans list
  end

  # GET /projects/:project_id/decomposition_plans/new_plan
  # Render the form for creating a new plan
  def new_plan
    @decomposition_plan = @project.decomposition_plans.build
    # Renders new_plan.html.erb which wraps the editor in a turbo-frame
  end

  # POST /projects/:project_id/decomposition_plans
  # Create and launch the planning agent
  def create
    user_input = params[:original_input]

    if user_input.blank?
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to @project, alert: "Please describe what you want to plan." }
      end
      return
    end

    @decomposition_plan = @project.decomposition_plans.build(
      original_input: user_input,
      created_by: current_user,
      status: "planning"
    )

    if @decomposition_plan.save
      begin
        agent = Agents::PlanningDecompositionAgent.new(@decomposition_plan)
        agent.launch

        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              "decomposition_plan_modal",
              partial: "decomposition_plans/editor",
              locals: { project: @project, plan: @decomposition_plan.reload, conversation: [] }
            )
          end
          format.html { redirect_to project_decomposition_plan_path(@project, @decomposition_plan) }
        end
      rescue Agents::PlanningDecompositionAgent::ProjectNotConfiguredError => e
        @decomposition_plan.destroy
        respond_to do |format|
          format.turbo_stream { head :unprocessable_entity }
          format.html { redirect_to @project, alert: e.message }
        end
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to @project, alert: @decomposition_plan.errors.full_messages.join(", ") }
      end
    end
  end

  # GET /projects/:project_id/decomposition_plans/:id
  def show
    @conversation = fetch_conversation

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "decomposition_plan_modal",
          partial: "decomposition_plans/editor",
          locals: { project: @project, plan: @decomposition_plan, conversation: @conversation }
        )
      end
    end
  end

  # POST /projects/:project_id/decomposition_plans/:id/followup
  # Send a follow-up message to the agent
  def followup
    message = params[:message]

    if message.blank?
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to project_decomposition_plan_path(@project, @decomposition_plan), alert: "Please provide a message." }
      end
      return
    end

    begin
      agent = Agents::PlanningDecompositionAgent.new(@decomposition_plan)
      agent.followup(message)

      # Set status back to planning since agent is working
      @decomposition_plan.update!(status: "planning")

      @conversation = fetch_conversation

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("decomposition_plan_chat", partial: "decomposition_plans/chat", locals: { plan: @decomposition_plan, conversation: @conversation }),
            turbo_stream.replace("decomposition_plan_status_value", html: "<div id='decomposition_plan_status_value' data-status='#{@decomposition_plan.status}' class='hidden'></div>".html_safe)
          ]
        end
        format.html { redirect_to project_decomposition_plan_path(@project, @decomposition_plan) }
      end
    rescue StandardError => e
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to project_decomposition_plan_path(@project, @decomposition_plan), alert: e.message }
      end
    end
  end

  # GET /projects/:project_id/decomposition_plans/:id/poll
  # Poll for agent status updates
  def poll
    begin
      if @decomposition_plan.agent_id && @decomposition_plan.status == "planning"
        check_agent_status
      end
    rescue => e
      Rails.logger.error "[DecompositionPlan #{@decomposition_plan.id}] Error in check_agent_status: #{e.message}"
    end

    @conversation = fetch_conversation

    # Extract plan if ready
    extracted_plan = nil
    if @decomposition_plan.status == "ready" && @decomposition_plan.plan_content.present?
      extractor = DecompositionPlanExtractor.new(@decomposition_plan.plan_content)
      extracted_plan = extractor.extract
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("decomposition_plan_chat", partial: "decomposition_plans/chat", locals: { plan: @decomposition_plan.reload, conversation: @conversation }),
          turbo_stream.update("decomposition_plan_preview", partial: "decomposition_plans/plan_preview", locals: { plan: @decomposition_plan, extracted: extracted_plan }),
          turbo_stream.replace("decomposition_plan_status_value", html: "<div id='decomposition_plan_status_value' data-status='#{@decomposition_plan.status}' class='hidden'></div>".html_safe)
        ]
      end
      format.html { redirect_to project_decomposition_plan_path(@project, @decomposition_plan) }
    end
  end

  # POST /projects/:project_id/decomposition_plans/:id/approve
  # Create all requests from the plan
  def approve
    selected_indices = params[:selected_requests]&.map(&:to_i)

    creator = RequestBatchCreator.new(@decomposition_plan)

    if creator.create_all(selected_indices: selected_indices)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.action(:redirect, project_path(@project))
        end
        format.html { redirect_to @project, notice: "Created #{creator.created_requests.count} requests in group '#{creator.request_group.name}'." }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to project_decomposition_plan_path(@project, @decomposition_plan), alert: creator.errors.join(", ") }
      end
    end
  end

  # POST /projects/:project_id/decomposition_plans/:id/cancel
  # Cancel the planning session
  def cancel
    @decomposition_plan.update!(status: "cancelled")

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.action(:redirect, project_path(@project))
      end
      format.html { redirect_to @project, notice: "Plan cancelled." }
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_decomposition_plan
    @decomposition_plan = @project.decomposition_plans.find(params[:id])
  end

  def fetch_conversation
    return [] unless @decomposition_plan.agent_id

    begin
      client = CursorApi::Client.new
      conv = client.get_conversation(@decomposition_plan.agent_id)
      conv["messages"] || []
    rescue CursorApi::Client::Error
      []
    end
  end

  def check_agent_status
    return unless @decomposition_plan.agent_id

    begin
      client = CursorApi::Client.new
      agent_status = client.get_agent(@decomposition_plan.agent_id)
      status_str = agent_status["status"]&.to_s&.upcase

      Rails.logger.info "[DecompositionPlan #{@decomposition_plan.id}] Agent status: #{status_str}"

      # Only transition when agent is truly FINISHED - agents send multiple messages while working
      # This matches the proven pattern from the request flow
      if status_str == "FINISHED"
        handle_agent_finished(client)
      end
    rescue CursorApi::Client::Error => e
      Rails.logger.error "[DecompositionPlan #{@decomposition_plan.id}] Error checking agent status: #{e.message}"
      # Silent fail - will try again on next poll
    end
  end

  def handle_agent_finished(client)
    conv = client.get_conversation(@decomposition_plan.agent_id)
    last_agent_msg = conv["messages"].reverse.find { |m| m["type"] == "assistant_message" }

    unless last_agent_msg
      Rails.logger.warn "[DecompositionPlan #{@decomposition_plan.id}] No assistant message found, setting to needs_clarification"
      @decomposition_plan.update!(status: "needs_clarification")
      return
    end

    content = last_agent_msg["text"]
    detected_status = DecompositionPlanExtractor.detect_status(content)

    Rails.logger.info "[DecompositionPlan #{@decomposition_plan.id}] Detected status: #{detected_status}, content length: #{content&.length}"

    case detected_status
    when :needs_clarification
      @decomposition_plan.update!(status: "needs_clarification")
    when :ready
      # Extract and save the plan content
      plan_content = DecompositionPlanExtractor.extract_plan_section(content) || content
      extractor = DecompositionPlanExtractor.new(plan_content)
      extracted = extractor.extract

      @decomposition_plan.update!(
        status: "ready",
        plan_content: plan_content,
        title: extracted[:title]
      )
    else
      # Fallback: if no status marker, check if plan section exists
      plan_section = DecompositionPlanExtractor.extract_plan_section(content)
      if plan_section.present?
        Rails.logger.info "[DecompositionPlan #{@decomposition_plan.id}] Found plan section without status marker, setting to ready"
        extractor = DecompositionPlanExtractor.new(plan_section)
        extracted = extractor.extract

        @decomposition_plan.update!(
          status: "ready",
          plan_content: plan_section,
          title: extracted[:title]
        )
      else
        Rails.logger.info "[DecompositionPlan #{@decomposition_plan.id}] No plan section found, setting to needs_clarification"
        @decomposition_plan.update!(status: "needs_clarification")
      end
    end
  end
end
