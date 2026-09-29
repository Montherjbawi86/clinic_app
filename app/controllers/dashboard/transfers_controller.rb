class Dashboard::TransfersController < ApplicationController
  before_action :require_login
  def index
    @transfers = Transfer.all
  end
end
