class DashboardController < ApplicationController
  def index
    @state = PlayerState.current
  end
end
