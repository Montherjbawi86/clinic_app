class Dashboard::AppointmentsController < ApplicationController
  before_action :require_login

  def index
    @appointments = Appointment.all.order(appointment_date: :asc)
    @appointment = Appointment.new
  end

  def create
    default_clinic = current_user.clinics.first || current_user.clinics.create!(name: "Main Clinic")
    @appointment = Appointment.new(appointment_params)
    @appointment.clinic_id = default_clinic.id
    @appointment.doctor_id = current_user.id
    @appointment.status ||= "confirmed"

    if @appointment.save
      redirect_to dashboard_appointments_path, notice: "Appointment scheduled successfully."
    else
      @appointments = Appointment.all.order(appointment_date: :asc)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    Appointment.find(params[:id]).destroy
    redirect_to dashboard_appointments_path, notice: "Appointment canceled."
  end

  private

  def appointment_params
    params.require(:appointment).permit(:patient_id, :appointment_date, :appointment_time, :reason)
  end
end
