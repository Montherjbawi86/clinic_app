class ClinicsController < ApplicationController
  before_action :require_login

  def switch
    clinic = current_user.clinics.find(params[:clinic_id])
    session[:clinic_id] = clinic.id
    redirect_back fallback_location: dashboard_path, notice: "Switched clinic."
  end
end
