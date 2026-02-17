# frozen_string_literal: true

class RequestsController < ApplicationController
  before_action :set_request, only: [:show, :update_plan, :comment, :poll, :send_to_asana]
  before_action :require_project, only: [:index, :new, :create]

  # GET /requests
  def index
    @requests = current_project.requests

    case params[:filter]
    when "created_by_me"
      @requests = @requests.created_by_user(current_user)
    when "drafts"
      @requests = @requests.drafts
    end

    @requests = @requests.recent
    @current_filter = params[:filter] || "all"
  end

  # GET /requests/:id
  # Shows the plan review page (for drafts) or the confirmed shaped task
  def show
  end

  # GET /requests/new
  def new
    @request = current_project.requests.build
  end

  # POST /requests
  # Called from intake page AFTER agent has drafted a plan.
  # Creates Request in "draft" status -- user will review before sending to Asana.
  def create
    @request = current_project.requests.build(request_params)
    @request.created_by = current_user
    @request.plan_content = params[:plan_content]
    @request.intake_agent_id = params[:agent_id] || session[:intake_agent_id]
    @request.status = "draft"

    ActiveRecord::Base.transaction do
      if @request.save
        # Extract structured data from the shaped plan
        if params[:plan_content].present?
          extracted = PlanExtractor.new(params[:plan_content]).extract
          @request.update!(extracted)
        end

        # Clear the intake session
        session.delete(:intake_agent_id)
        session.delete(:intake_original_input)

        respond_to do |format|
          format.html { redirect_to @request, notice: "Plan drafted. Review and edit before sending to Asana." }
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

  # PATCH /requests/:id/update_plan
  # Auto-save plan content edits from the plan editor
  def update_plan
    plan_content = params[:plan_content]

    if plan_content.blank?
      head :unprocessable_entity
      return
    end

    @request.update!(plan_content: plan_content)

    # Re-extract structured fields from updated plan
    extracted = PlanExtractor.new(plan_content).extract
    @request.update!(extracted)

    render json: { success: true, saved_at: Time.current.iso8601 }
  rescue ActiveRecord::RecordInvalid => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # POST /requests/:id/comment
  # Send a follow-up message to the intake agent for plan refinement
  def comment
    message = params[:message]

    if message.blank?
      respond_to do |format|
        format.json { render json: { success: false, error: "Message cannot be empty." }, status: :unprocessable_entity }
        format.html { redirect_to @request, alert: "Message cannot be empty." }
      end
      return
    end

    unless @request.agent_available?
      respond_to do |format|
        format.json { render json: { success: false, error: "No agent available." }, status: :unprocessable_entity }
        format.html { redirect_to @request, alert: "No agent available for this request." }
      end
      return
    end

    # Save as a comment record
    @request.comments.create!(
      user: current_user,
      author_type: "user",
      author_name: current_user&.name || "Web User",
      content: message,
      comment_type: "agent_chat"
    )

    # Send follow-up to the agent
    begin
      client = CursorApi::Client.new
      client.followup(@request.intake_agent_id, prompt: message)
    rescue CursorApi::Client::Error => e
      Rails.logger.error "[Nova Flow] Failed to send followup to agent: #{e.message}"
    end

    respond_to do |format|
      format.json { render json: { success: true } }
      format.html { redirect_to @request }
    end
  end

  # GET /requests/:id/poll
  # Check agent status after a follow-up message, update plan content if agent responded
  def poll
    unless @request.agent_available?
      render json: { status: "no_agent" }
      return
    end

    begin
      client = CursorApi::Client.new
      agent_status = client.get_agent(@request.intake_agent_id)
      status_str = agent_status["status"]&.to_s&.upcase

      if status_str == "FINISHED"
        # Agent finished -- extract the latest plan from conversation
        conversation = client.get_conversation(@request.intake_agent_id)
        messages = conversation["messages"] || []

        last_assistant = messages.reverse.find { |m| m["type"] == "assistant_message" }
        if last_assistant
          new_content = last_assistant["text"] || ""
          # Extract just the Implementation Plan section, stripping preamble and status markers
          cleaned = PlanExtractor.extract_plan_section(new_content)
          if cleaned.blank?
            # Fallback: strip STATUS markers if no plan section heading found
            cleaned = new_content
              .gsub(/---\s*STATUS:\s*clarified\s*$/i, "")
              .gsub(/STATUS:\s*clarified/i, "")
              .strip
          end

          # Update the plan content
          @request.update!(plan_content: cleaned)

          # Re-extract structured fields
          extracted = PlanExtractor.new(cleaned).extract
          @request.update!(extracted)

          # Save agent response as comment
          @request.comments.create!(
            author_type: "agent",
            author_name: "Nova Agent",
            content: cleaned.truncate(500),
            comment_type: "agent_chat"
          )
        end

        render json: { status: "finished", plan_content: @request.plan_content }
      else
        render json: { status: "processing" }
      end
    rescue CursorApi::Client::Error => e
      Rails.logger.error "[Nova Flow] Failed to poll agent: #{e.message}"
      render json: { status: "error", error: e.message }
    end
  end

  # POST /requests/:id/send_to_asana
  # Finalize the shaped task and push to Asana
  def send_to_asana
    unless @request.draft?
      redirect_to @request, alert: "This task has already been sent to Asana."
      return
    end

    # Re-extract structured fields from the latest plan content
    if @request.plan_content.present?
      extracted = PlanExtractor.new(@request.plan_content).extract
      @request.update!(extracted)
    end

    # Push to Asana if project is configured
    if @request.project.asana_configured?
      begin
        asana_result = Asana::TaskCreator.new(
          project: @request.project,
          request: @request,
          plan_content: @request.plan_content
        ).create_task

        @request.update!(
          status: "sent_to_asana",
          asana_task_gid: asana_result[:gid],
          asana_task_url: asana_result[:url]
        )

        redirect_to @request, notice: "Shaped task sent to Asana!"
      rescue Asana::Client::Error => e
        Rails.logger.error "[Nova Flow] Failed to create Asana task: #{e.message}"
        redirect_to @request, alert: "Failed to push to Asana: #{e.message}"
      end
    else
      # No Asana configured -- just mark as sent
      @request.update!(status: "sent_to_asana")
      redirect_to @request, notice: "Shaped task finalized. Connect Asana to auto-push tasks."
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
end
