#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Rewriting controllers…"

mkdir -p app/controllers/dashboard

cat > app/controllers/dashboard/base_controller.rb <<'RUBY'
class Dashboard::BaseController < ApplicationController
  before_action :require_login
  before_action :set_current_clinic

  helper_method :current_clinic

  private

  def current_clinic
    @current_clinic
  end

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
        @current_clinic = Clinic.create!(name: "Main Clinic", owner: current_user, name_ar: "العيادة الرئيسية")
        ClinicMember.find_or_create_by!(clinic: @current_clinic, user: current_user) { |m| m.role = "owner" }
      else
        @current_clinic = current_user.clinics.first || current_user.owned_clinics.first
      end
    end

    session[:clinic_id] = @current_clinic.id
  end
end
RUBY

cat > app/controllers/dashboard/overview_controller.rb <<'RUBY'
class Dashboard::OverviewController < Dashboard::BaseController
  def index
    @patients_count     = current_clinic.patients.count
    @appointments_today = current_clinic.appointments.for_today.count
    @appointments_week  = current_clinic.appointments.where(appointment_date: Date.current..(Date.current + 7.days)).count
    @revenue_this_month = current_clinic.payments.paid.where(created_at: Time.current.all_month).sum(:amount)
    @pending_payments   = current_clinic.payments.pending.sum(:amount)
    @unread_count       = current_user.notifications.unread.count
    @recent_patients    = current_clinic.patients.order(created_at: :desc).limit(5)
    @today_appointments = current_clinic.appointments
                                       .includes(:patient, :doctor)
                                       .for_today
                                       .order(:appointment_time)
    @recent_payments    = current_clinic.payments.paid.includes(:patient, :user).recent.limit(5)
  end
end
RUBY

cat > app/controllers/dashboard/patients_controller.rb <<'RUBY'
class Dashboard::PatientsController < Dashboard::BaseController
  before_action :set_patient, only: [:show, :edit, :update, :destroy]

  def index
    @patients = current_clinic.patients.order(created_at: :desc)
    @patients = @patients.search(params[:q]) if params[:q].present?
  end

  def show
    @appointments = @patient.appointments.includes(:doctor).recent.limit(10)
    @reports      = @patient.medical_reports.includes(:doctor).recent.limit(10)
    @medications  = @patient.medications.active.recent.limit(10)
    @payments     = @patient.payments.recent.limit(10)
  end

  def new
    @patient = current_clinic.patients.new
  end

  def edit; end

  def create
    @patient = current_clinic.patients.new(patient_params)
    if @patient.save
      redirect_to dashboard_patient_path(@patient), notice: "Patient registered successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @patient.update(patient_params)
      redirect_to dashboard_patient_path(@patient), notice: "Patient updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @patient.discard
    redirect_to dashboard_patients_path, notice: "Patient archived."
  rescue NoMethodError
    @patient.destroy
    redirect_to dashboard_patients_path, notice: "Patient removed."
  end

  private

  def set_patient
    @patient = current_clinic.patients.find(params[:id])
  end

  def patient_params
    params.require(:patient).permit(
      :name, :name_ar, :phone, :gender, :age, :date_of_birth, :medical_history,
      :national_id, :blood_type, :address, :emergency_name, :emergency_phone,
      :allergies, :chronic_conditions, :insurance_provider, :insurance_number
    )
  end
end
RUBY

cat > app/controllers/dashboard/appointments_controller.rb <<'RUBY'
class Dashboard::AppointmentsController < Dashboard::BaseController
  before_action :set_appointment, only: [:show, :destroy]

  def index
    @appointments = current_clinic.appointments
                                   .includes(:patient, :doctor)
                                   .order(appointment_date: :asc, appointment_time: :asc)
    @appointments = @appointments.where(appointment_date: params[:date]) if params[:date].present?
    @appointment = current_clinic.appointments.new
  end

  def show; end

  def create
    @appointment = current_clinic.appointments.new(appointment_params)
    @appointment.doctor ||= current_user
    @appointment.status ||= "scheduled"

    if @appointment.save
      redirect_to dashboard_appointments_path, notice: "Appointment scheduled successfully."
    else
      @appointments = current_clinic.appointments
                                     .includes(:patient, :doctor)
                                     .order(appointment_date: :asc, appointment_time: :asc)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @appointment.destroy
    redirect_to dashboard_appointments_path, notice: "Appointment canceled."
  end

  private

  def set_appointment
    @appointment = current_clinic.appointments.find(params[:id])
  end

  def appointment_params
    params.require(:appointment).permit(
      :patient_id, :doctor_id, :appointment_date, :appointment_time,
      :duration_minutes, :reason, :reason_ar, :notes, :status
    )
  end
end
RUBY

cat > app/controllers/dashboard/reports_controller.rb <<'RUBY'
class Dashboard::ReportsController < Dashboard::BaseController
  def index
    @reports = current_clinic.medical_reports
                             .includes(:patient, :doctor)
                             .recent
    @report = current_clinic.medical_reports.new
    @patients = current_clinic.patients.order(:name)
    @appointments = current_clinic.appointments.upcoming
  end

  def create
    @report = current_clinic.medical_reports.new(report_params)
    @report.doctor = current_user

    if @report.save
      redirect_to dashboard_reports_path, notice: "Medical report added successfully."
    else
      @reports = current_clinic.medical_reports.includes(:patient, :doctor).recent
      @patients = current_clinic.patients.order(:name)
      @appointments = current_clinic.appointments.upcoming
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    report = current_clinic.medical_reports.find(params[:id])
    report.destroy
    redirect_to dashboard_reports_path, notice: "Report removed."
  end

  private

  def report_params
    params.require(:medical_report).permit(
      :patient_id, :appointment_id, :diagnosis, :diagnosis_ar,
      :treatment, :treatment_ar, :notes, :notes_ar, :follow_up_date, :status
    )
  end
end
RUBY

cat > app/controllers/dashboard/medications_controller.rb <<'RUBY'
class Dashboard::MedicationsController < Dashboard::BaseController
  def index
    @medications = current_clinic.medications
                                  .includes(:patient, :doctor)
                                  .recent
    @medication = current_clinic.medications.new
    @patients = current_clinic.patients.order(:name)
  end

  def create
    @medication = current_clinic.medications.new(medication_params)
    @medication.doctor = current_user

    if @medication.save
      redirect_to dashboard_medications_path, notice: "Medication prescribed successfully."
    else
      @medications = current_clinic.medications.includes(:patient, :doctor).recent
      @patients = current_clinic.patients.order(:name)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    medication = current_clinic.medications.find(params[:id])
    medication.destroy
    redirect_to dashboard_medications_path, notice: "Prescription removed."
  end

  private

  def medication_params
    params.require(:medication).permit(
      :patient_id, :appointment_id, :name, :name_ar, :dosage, :frequency,
      :duration, :route, :quantity, :refills, :instructions, :status
    )
  end
end
RUBY

cat > app/controllers/dashboard/payments_controller.rb <<'RUBY'
class Dashboard::PaymentsController < Dashboard::BaseController
  def index
    @payments = current_clinic.payments.includes(:user, :patient).recent
    @payment  = current_clinic.payments.new
    @patients = current_clinic.patients.order(:name)
    @total_paid    = current_clinic.payments.paid.sum(:amount)
    @total_pending = current_clinic.payments.pending.sum(:amount)
  end

  def create
    @payment = current_clinic.payments.new(payment_params)
    @payment.user = current_user

    if @payment.save
      redirect_to dashboard_payments_path, notice: "Payment recorded."
    else
      @payments = current_clinic.payments.includes(:user, :patient).recent
      @patients = current_clinic.patients.order(:name)
      @total_paid    = current_clinic.payments.paid.sum(:amount)
      @total_pending = current_clinic.payments.pending.sum(:amount)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    payment = current_clinic.payments.find(params[:id])
    payment.destroy
    redirect_to dashboard_payments_path, notice: "Payment removed."
  end

  private

  def payment_params
    params.require(:payment).permit(
      :patient_id, :appointment_id, :amount, :currency, :method,
      :status, :reference, :notes, :paid_at
    )
  end
end
RUBY

cat > app/controllers/dashboard/transfers_controller.rb <<'RUBY'
class Dashboard::TransfersController < Dashboard::BaseController
  def index
    @transfers = current_clinic.transfers
                               .includes(:patient, :from_clinic, :to_clinic)
                               .order(created_at: :desc)
    @transfer = current_clinic.transfers.new
    @destination_clinics = Clinic.where.not(id: current_clinic.id).order(:name)
  end

  def create
    @transfer = current_clinic.transfers.new(transfer_params)
    @transfer.from_clinic = current_clinic

    if @transfer.save
      redirect_to dashboard_transfers_path, notice: "Transfer request created."
    else
      @transfers = current_clinic.transfers.includes(:patient, :from_clinic, :to_clinic).order(created_at: :desc)
      @destination_clinics = Clinic.where.not(id: current_clinic.id).order(:name)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    transfer = current_clinic.transfers.find(params[:id])
    transfer.destroy
    redirect_to dashboard_transfers_path, notice: "Transfer removed."
  end

  private

  def transfer_params
    params.require(:transfer).permit(:patient_id, :to_clinic_id, :reason)
  end
end
RUBY

cat > app/controllers/dashboard/clinics_controller.rb <<'RUBY'
class Dashboard::ClinicsController < Dashboard::BaseController
  def index
    @clinics = current_user.clinics.includes(:owner).order(:name)
    @clinic  = Clinic.new
  end

  def show
    @clinic  = current_user.clinics.find(params[:id])
    @members = @clinic.clinic_members.includes(:user)
    @stats   = {
      patients:     @clinic.patients.count,
      appointments: @clinic.appointments.count,
      reports:      @clinic.medical_reports.count
    }
  end
end
RUBY

cat > app/controllers/dashboard/subscriptions_controller.rb <<'RUBY'
class Dashboard::SubscriptionsController < Dashboard::BaseController
  def index
    @subscriptions = current_clinic.subscriptions.order(created_at: :desc)
  end
end
RUBY

cat > app/controllers/dashboard/chat_controller.rb <<'RUBY'
class Dashboard::ChatController < Dashboard::BaseController
  def index
    messages = current_user.chat_messages.recent.limit(50)
    render json: { messages: messages }
  end

  def create
    text     = params[:message].to_s.strip
    language = params[:language] == "en" ? "en" : "ar"

    return render json: { error: "Empty message" }, status: :unprocessable_entity if text.blank?

    reply = language == "en" ?
      "Hello! I am your medical assistant. How can I help you with your clinic records today?" :
      "مرحباً! أنا مساعدك الطبي. كيف يمكنني مساعدتك في سجلات عيادتك اليوم؟"

    ChatMessage.create!(user: current_user, sender_role: "user",      content: text,  language: language)
    ChatMessage.create!(user: current_user, sender_role: "assistant", content: reply, language: language)

    render json: { reply: reply, language: language }
  end
end
RUBY

cat > app/controllers/clinics_controller.rb <<'RUBY'
class ClinicsController < ApplicationController
  before_action :require_login

  def switch
    clinic = current_user.clinics.find(params[:clinic_id])
    session[:clinic_id] = clinic.id
    redirect_back fallback_location: dashboard_path, notice: "Switched clinic."
  end
end
RUBY

echo "==> Controllers rewritten."
echo ""
echo "==> Verifying (autoload check)…"
bin/rails runner 'Dashboard::BaseController; Dashboard::PatientsController; Dashboard::PaymentsController; puts "OK"' 2>&1 | tail -5

echo "==> Done."
