# frozen_string_literal: true

class DesignGuidancesController < ApplicationController
  before_action :set_request

  # POST /requests/:request_id/design_guidance
  def create
    @design_guidance = @request.build_design_guidance(design_guidance_params)
    @design_guidance.user = current_user
    @design_guidance.provided_by = current_user&.name || "Web User"

    if @design_guidance.save
      redirect_to @request, notice: "Design guidance saved successfully."
    else
      redirect_to @request, alert: "Failed to save design guidance: #{@design_guidance.errors.full_messages.join(', ')}"
    end
  end

  # PATCH /requests/:request_id/design_guidance
  def update
    @design_guidance = @request.design_guidance || @request.build_design_guidance

    # Handle image attachments - append new images if any
    if params[:design_guidance][:images].present?
      params[:design_guidance][:images].each do |image|
        @design_guidance.images.attach(image) if image.present?
      end
    end

    # Update other attributes
    if @design_guidance.update(design_guidance_params.except(:images))
      redirect_to @request, notice: "Design guidance updated successfully."
    else
      redirect_to @request, alert: "Failed to update design guidance: #{@design_guidance.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_request
    @request = Request.find(params[:request_id])
  end

  def design_guidance_params
    params.require(:design_guidance).permit(
      :specifications,
      images: [],
      figma_links_attributes: [:id, :url, :description, :position, :_destroy]
    )
  end
end
