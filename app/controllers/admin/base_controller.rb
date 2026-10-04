class Admin::BaseController < ApplicationController
  before_action :require_login
  before_action :require_super_admin

  layout "admin"

  private

  def require_super_admin
    unless current_user&.super_admin?
      redirect_to dashboard_path, alert: "Access denied"
    end
  end
end
