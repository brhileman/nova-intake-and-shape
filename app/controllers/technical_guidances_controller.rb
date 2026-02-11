# frozen_string_literal: true

class TechnicalGuidancesController < ApplicationController
  before_action :set_request

  # POST /requests/:request_id/technical_guidance
  def create
    @technical_guidance = @request.build_technical_guidance(technical_guidance_params)
    @technical_guidance.user = current_user

    if @technical_guidance.save
      respond_to do |format|
        format.html { redirect_to @request, notice: "Technical guidance saved successfully." }
        format.json { render json: { success: true, saved_at: Time.current.iso8601 } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @request, alert: "Failed to save technical guidance: #{@technical_guidance.errors.full_messages.join(', ')}" }
        format.json { render json: { success: false, error: @technical_guidance.errors.full_messages.join(', ') }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /requests/:request_id/technical_guidance
  def update
    @technical_guidance = @request.technical_guidance || @request.build_technical_guidance(user: current_user)

    if @technical_guidance.update(technical_guidance_params)
      respond_to do |format|
        format.html { redirect_to @request, notice: "Technical guidance updated successfully." }
        format.json { render json: { success: true, saved_at: Time.current.iso8601 } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @request, alert: "Failed to update technical guidance: #{@technical_guidance.errors.full_messages.join(', ')}" }
        format.json { render json: { success: false, error: @technical_guidance.errors.full_messages.join(', ') }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_request
    @request = Request.find(params[:request_id])
  end

  def technical_guidance_params
    params.require(:technical_guidance).permit(:notes)
  end
end
