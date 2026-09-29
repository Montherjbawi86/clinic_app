class Dashboard::OverviewController < ApplicationController
  before_action :require_login

  def index
    @clinics_count = Clinic.count
    @patients_count = Patient.count
    @appointments_count = Appointment.count
  end
end
