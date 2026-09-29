class Dashboard::PatientsController < ApplicationController
  before_action :require_login

  def index
    @patients = Patient.all.order(created_at: :desc)
  end

  def new
    @patient = Patient.new
  end

  def create
    # Assign a default clinic if none exists yet
    default_clinic = current_user.clinics.first || current_user.clinics.create!(name: "Main Clinic")
    @patient = Patient.new(patient_params)
    @patient.clinic_id = default_clinic.id

    if @patient.save
      redirect_to dashboard_patients_path, notice: "Patient registered successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    patient = Patient.find(params[:id])
    patient.destroy
    redirect_to dashboard_patients_path, notice: "Patient removed successfully."
  end

  private

  def patient_params
    params.require(:patient).permit(:name, :name_ar, :phone, :gender, :age, :date_of_birth, :medical_history)
  end
end
