# frozen_string_literal: true

class RequestsController < ApplicationController
  before_action :set_request, only: [:show]
  before_action :require_project, only: [:index, :new, :create]

  # GET /requests
  def index
    @requests = current_project.requests

    # Apply filters based on params
    case params[:filter]
    when "created_by_me"
      @requests = @requests.created_by_user(current_user)
    end

    @requests = @requests.recent
    @current_filter = params[:filter] || "all"
  end

  # GET /requests/:id
  def show
  end

  # GET /requests/new
  def new
    @request = current_project.requests.build
  end

  # POST /requests
  # Called from intake page AFTER agent has drafted a shaped task
  def create
    @request = current_project.requests.build(request_params)
    @request.created_by = current_user
    @request.plan_content = params[:plan_content]

    ActiveRecord::Base.transaction do
      if @request.save
        # Extract structured data from the shaped plan
        if params[:plan_content].present?
          extracted = PlanExtractor.new(params[:plan_content]).extract
          @request.update!(extracted)
        end

        # Push to Asana if project is configured
        if current_project.asana_configured?
          begin
            asana_result = Asana::TaskCreator.new(
              project: current_project,
              request: @request,
              plan_content: params[:plan_content]
            ).create_task

            @request.update!(
              asana_task_gid: asana_result[:gid],
              asana_task_url: asana_result[:url]
            )
          rescue Asana::Client::Error => e
            Rails.logger.error "[Nova Flow] Failed to create Asana task: #{e.message}"
            # Don't fail the request creation -- task is saved locally
            flash[:alert] = "Shaped task saved locally but failed to push to Asana: #{e.message}"
          end
        end

        respond_to do |format|
          format.html { redirect_to @request, notice: asana_notice }
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

  def asana_notice
    if @request.pushed_to_asana?
      "Shaped task created and pushed to Asana."
    elsif current_project.asana_configured?
      "Shaped task saved locally (Asana push failed -- see alert)."
    else
      "Shaped task saved. Connect an Asana project to auto-push tasks."
    end
  end
end
