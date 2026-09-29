class Dashboard::MedicationsController < ApplicationController
  before_action :require_login

  def index
    @medications = Medication.all.order(created_at: :desc)
    @medication = Medication.new
  end

  def create
    default_clinic = current_user.clinics.first || current_user.clinics.create!(name: "Main Clinic")
    @medication = Medication.new(medication_params)
    @medication.clinic_id = default_clinic.id
    @medication.doctor_id = current_user.id

    if @medication.save
      redirect_to dashboard_medications_path, notice: "Medication item prescribed successfully."
    else
      @medications = Medication.all.order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  private

  def medication_params
    params.require(:medication).permit(:patient_id, :name, :dosage, :instructions)
  end
end
