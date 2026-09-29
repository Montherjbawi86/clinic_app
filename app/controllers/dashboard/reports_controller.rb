class Dashboard::ReportsController < ApplicationController
  before_action :require_login

  def index
    @reports = MedicalReport.all.order(created_at: :desc)
    @report = MedicalReport.new
  end

  def create
    default_clinic = current_user.clinics.first || current_user.clinics.create!(name: "Main Clinic")
    @report = MedicalReport.new(report_params)
    @report.clinic_id = default_clinic.id
    @report.doctor_id = current_user.id

    if @report.save
      redirect_to dashboard_reports_path, notice: "Medical report added successfully."
    else
      @reports = MedicalReport.all.order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  private

  def report_params
    params.require(:medical_report).permit(:patient_id, :diagnosis, :prescription, :notes)
  end
end
