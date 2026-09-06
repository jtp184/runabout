class CommandsController < ApplicationController
  def create
    state = PlayerState.current
    command = PlayerCommand.new(action: params[:command], value: params[:value], bus_name: params[:bus_name], track_id: params[:track_id])
    if state.bus_name.blank? || command.bus_name != state.bus_name || command.track_id != state.track_id
      redirect_to root_path, alert: "Player or track changed. Please try again.", status: :see_other
    elsif command.save
      head :accepted
    else
      render plain: command.errors.full_messages.to_sentence, status: :unprocessable_entity
    end
  end
end
