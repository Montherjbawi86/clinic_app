#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Setting up prescription PDF…"

bundle add prawn
bundle add prawn-table
bundle install

mkdir -p app/services
cat > app/services/prescription_pdf.rb <<'RUBY'
require "prawn"
require "prawn/table"

class PrescriptionPdf
  FONT_PATH = Rails.root.join("app/assets/fonts/Cairo-Regular.ttf")
  FONT_BOLD = Rails.root.join("app/assets/fonts/Cairo-Bold.ttf")

  def initialize(appointment:, clinic:, doctor:, patient:, medications:)
    @appointment = appointment
    @clinic      = clinic
    @doctor      = doctor
    @patient     = patient
    @medications = medications
  end

  def render
    Prawn::Document.new(page_size: "A4", margin: 40) do |pdf|
      register_fonts(pdf)
      draw_header(pdf)
      draw_patient_info(pdf)
      draw_diagnosis(pdf)
      draw_medications(pdf)
      draw_footer(pdf)
    end.render
  end

  private

  def register_fonts(pdf)
    if File.exist?(FONT_PATH)
      pdf.font_families.update(
        "Cairo" => {
          normal: FONT_PATH.to_s,
          bold:   File.exist?(FONT_BOLD) ? FONT_BOLD.to_s : FONT_PATH.to_s,
        }
      )
      pdf.font "Cairo"
    end
  end

  def draw_header(pdf)
    pdf.text @clinic.name.to_s, size: 20, style: :bold, align: :center
    pdf.text @clinic.address.to_s, size: 10, align: :center
    pdf.text "هاتف: #{@clinic.phone}", size: 10, align: :center if @clinic.phone.present?
    pdf.move_down 10
    pdf.stroke_horizontal_rule
    pdf.move_down 15
    pdf.text "وصفة طبية", size: 16, style: :bold, align: :center
    pdf.move_down 15
  end

  def draw_patient_info(pdf)
    data = [
      ["اسم المريض:", @patient.display_name.to_s, "التاريخ:", @appointment.appointment_date.to_s],
      ["العمر:", (@patient.age.presence || @patient.age_from_dob).to_s, "الطبيب:", "د. #{@doctor.name}"],
    ]
    pdf.table(data, width: pdf.bounds.width, cell_style: { border_width: 0, size: 11 }) do
      cells.padding = [4, 6]
      column(0).style(style: :bold)
      column(2).style(style: :bold)
    end
    pdf.move_down 15
  end

  def draw_diagnosis(pdf)
    return unless @appointment.respond_to?(:visit_notes) && @appointment.visit_notes.present?
    pdf.text "ملاحظات الزيارة:", style: :bold
    pdf.text @appointment.visit_notes, size: 11
    pdf.move_down 15
  end

  def draw_medications(pdf)
    pdf.text "الأدوية الموصوفة:", style: :bold, size: 13
    pdf.move_down 8

    if @medications.any?
      rows = [["#", "الدواء", "الجرعة", "التكرار", "المدة", "ملاحظات"]]
      @medications.each_with_index do |m, i|
        rows << [
          i + 1,
          m.display_name.to_s,
          m.dosage.to_s,
          m.frequency.to_s,
          m.duration.to_s,
          m.instructions.to_s.truncate(40)
        ]
      end

      pdf.table(rows, header: true, width: pdf.bounds.width) do
        row(0).style(background_color: "0D9488", text_color: "FFFFFF", font_style: :bold, align: :center)
        cells.padding = [6, 8]
        cells.size   = 10
        cells.border_color = "E2E8F0"
      end
    else
      pdf.text "لا توجد أدوية موصوفة.", size: 11, color: "888888"
    end
  end

  def draw_footer(pdf)
    pdf.move_down 40
    pdf.stroke_horizontal_rule
    pdf.move_down 20
    pdf.text "توقيع الطبيب: ____________________", size: 11, align: :right
    pdf.move_down 10
    pdf.text "هذه الوصفة صادرة إلكترونياً من ClinicApp", size: 9, align: :center, color: "888888"
  end
end
RUBY

echo "==> Service written: app/services/prescription_pdf.rb"

# ============================================================
# Add route — full rewrite to avoid sed regex issues
# ============================================================
cat > config/routes.rb <<'ROUTES'
Rails.application.routes.draw do
  root "home#index"

  resource  :session,       only: [:new, :create, :destroy]
  resources :registrations, only: [:new, :create]

  post "/switch_clinic", to: "clinics#switch", as: :switch_clinic
  post "/switch_locale", to: "locales#update", as: :switch_locale

  get   "/profile",           to: "profile#show",            as: :profile
  get   "/profile/edit",      to: "profile#edit",            as: :edit_profile
  patch "/profile",           to: "profile#update"
  patch "/profile/password",  to: "profile#update_password", as: :update_profile_password

  resources :notifications, only: [:index, :destroy] do
    member do
      post :mark_read
    end
    collection do
      post :mark_all_read
    end
  end

  namespace :dashboard do
    root to: "overview#index"

    resources :clinics, only: [:index, :show]

    resources :patients, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
      member do
        get :timeline
      end
      resources :medical_images, only: [:index, :create, :show, :destroy], controller: "medical_images"
    end

    resources :appointments, only: [:index, :show, :create, :destroy] do
      member do
        patch :check_in
        patch :start_visit
        patch :complete
        patch :cancel
        patch :no_show
        get   :prescription
      end
    end

    resources :reports,       only: [:index, :show, :create, :destroy]
    resources :medications,   only: [:index, :create, :destroy]
    resources :transfers,     only: [:index, :create, :destroy]
    resources :payments,      only: [:index, :create, :destroy]
    resources :subscriptions, only: [:index]

    get  "chat", to: "chat#index", as: :chat
    post "chat", to: "chat#create"
  end

  get "/dashboard", to: "dashboard/overview#index", as: :dashboard
end
ROUTES

echo "==> Routes written"

# ============================================================
# Update appointments controller — full rewrite
# ============================================================
cat > app/controllers/dashboard/appointments_controller.rb <<'RUBY'
class Dashboard::AppointmentsController < Dashboard::BaseController
  before_action :set_appointment, only: [:show, :destroy, :check_in, :start_visit, :complete, :cancel, :no_show, :prescription]

  def index
    base = current_clinic.appointments.includes(:patient, :doctor, :checked_in_by, :cancelled_by)

    base = base.where(status: params[:status])         if params[:status].present?
    base = base.where(appointment_date: params[:date]) if params[:date].present?
    base = base.where(doctor_id: params[:doctor_id])   if params[:doctor_id].present?

    @filter = params[:filter].presence || "all"
    base =
      case @filter
      when "today"     then base.for_today
      when "upcoming"  then base.upcoming.open
      when "open"      then base.open
      when "completed" then base.completed
      when "cancelled" then base.cancelled
      else base
      end

    @appointments = base.order(appointment_date: :asc, appointment_time: :asc)

    @appointment = current_clinic.appointments.new
    @doctors     = current_clinic.members.where(clinic_members: { role: %w[doctor owner] })
    @counts = {
      all:       current_clinic.appointments.count,
      today:     current_clinic.appointments.for_today.count,
      upcoming:  current_clinic.appointments.upcoming.open.count,
      open:      current_clinic.appointments.open.count,
      completed: current_clinic.appointments.completed.count,
      cancelled: current_clinic.appointments.cancelled.count
    }
  end

  def show
    @report      = @appointment.medical_report || current_clinic.medical_reports.new(appointment: @appointment)
    @medication  = current_clinic.medications.new(appointment: @appointment, patient: @appointment.patient)
    @medications = @appointment.medications
  end

  def create
    @appointment = current_clinic.appointments.new(appointment_params)
    @appointment.doctor ||= current_user
    @appointment.status ||= "scheduled"

    if @appointment.save
      redirect_to dashboard_appointments_path, notice: t("appointments.scheduled")
    else
      @doctors      = current_clinic.members.where(clinic_members: { role: %w[doctor owner] })
      @appointments = current_clinic.appointments.includes(:patient, :doctor).order(appointment_date: :asc, appointment_time: :asc)
      @counts = { all: 0, today: 0, upcoming: 0, open: 0, completed: 0, cancelled: 0 }
      render :index, status: :unprocessable_entity
    end
  end

  def check_in
    if @appointment.check_in!(current_user)
      redirect_to dashboard_appointment_path(@appointment), notice: t("appointments.checked_in_notice")
    else
      redirect_to dashboard_appointments_path, alert: @appointment.errors.full_messages.to_sentence
    end
  end

  def start_visit
    if @appointment.start_visit!(current_user)
      redirect_to dashboard_appointment_path(@appointment), notice: t("appointments.started_notice")
    else
      redirect_to dashboard_appointments_path, alert: "Could not start visit."
    end
  end

  def complete
    if @appointment.complete!(current_user,
                              notes: params[:visit_notes],
                              notes_ar: params[:visit_notes_ar],
                              vitals: params[:vitals],
                              follow_up_date: params[:follow_up_date])
      redirect_to dashboard_appointment_path(@appointment), notice: t("appointments.completed_notice")
    else
      redirect_to dashboard_appointment_path(@appointment), alert: @appointment.errors.full_messages.to_sentence
    end
  end

  def cancel
    if @appointment.cancel!(current_user, reason: params[:cancellation_reason])
      redirect_to dashboard_appointments_path, notice: t("appointments.cancelled_notice")
    else
      redirect_to dashboard_appointment_path(@appointment), alert: "Could not cancel."
    end
  end

  def no_show
    @appointment.mark_no_show!(current_user)
    redirect_to dashboard_appointments_path, notice: t("appointments.no_show_notice")
  end

  def prescription
    pdf_data = PrescriptionPdf.new(
      appointment: @appointment,
      clinic:      current_clinic,
      doctor:      @appointment.doctor || current_user,
      patient:     @appointment.patient,
      medications: @appointment.medications
    ).render

    send_data pdf_data,
              filename: "prescription-#{@appointment.id}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  def destroy
    @appointment.destroy
    redirect_to dashboard_appointments_path, notice: t("appointments.destroyed_notice")
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

echo "==> Controller written"
echo "==> Done."
echo ""
echo "Next: restart with bin/dev, then visit /dashboard/appointments/:id"
