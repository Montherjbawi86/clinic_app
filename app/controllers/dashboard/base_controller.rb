class Dashboard::BaseController < ApplicationController
  layout "dashboard3"

  before_action :require_login
  before_action :set_current_clinic

  private

  def set_current_clinic
    clinic_id = session[:clinic_id] || current_user.clinic_members.first&.clinic_id

    @current_clinic =
      if clinic_id
        current_user.clinics.find_by(id: clinic_id)
      else
        current_user.clinics.first
      end

    unless @current_clinic
      if current_user.owned_clinics.empty?
        @current_clinic = Clinic.create!(name: "Main Clinic", owner: current_user)
        ClinicMember.find_or_create_by!(clinic: @current_clinic, user: current_user) { |m| m.role = "owner" }
      else
        @current_clinic = current_user.owned_clinics.first
      end
    end

    session[:clinic_id] = @current_clinic.id
  end
end
