# frozen_string_literal: true

class RequestGroupsController < ApplicationController
  before_action :set_project
  before_action :set_request_group, only: [:destroy]

  # POST /projects/:project_id/request_groups
  def create
    @request_group = @project.request_groups.build(request_group_params)
    @request_group.created_by = current_user

    if @request_group.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "request_groups_options",
            partial: "request_groups/group_options",
            locals: { project: @project, selected_group_id: @request_group.id }
          )
        end
        format.html { redirect_to @project, notice: "Group created successfully." }
        format.json { render json: @request_group, status: :created }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to @project, alert: @request_group.errors.full_messages.join(", ") }
        format.json { render json: { errors: @request_group.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/:project_id/request_groups/:id
  def destroy
    # Nullify all requests in this group before destroying
    @request_group.requests.update_all(request_group_id: nil)
    @request_group.destroy

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "request_groups_options",
          partial: "request_groups/group_options",
          locals: { project: @project, selected_group_id: nil }
        )
      end
      format.html { redirect_to @project, notice: "Group deleted." }
      format.json { head :no_content }
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_request_group
    @request_group = @project.request_groups.find(params[:id])
  end

  def request_group_params
    params.require(:request_group).permit(:name, :description)
  end
end
