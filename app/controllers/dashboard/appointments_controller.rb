class Dashboard::AppointmentsController < Dashboard::BaseController
  before_action :set_appointment, only: [:show, :destroy, :check_in, :start_visit, :complete, :cancel, :no_show, :prescription, :send_reminder, :accept_booking, :ics, :wizard, :wizard_save]

  def index
    base = current_clinic.appointments.includes(:patient, :doctor, :checked_in_by, :cancelled_by)

    base = base.where(status: params[:status])         if params[:status].present?
    base = base.where(appointment_date: params[:date]) if params[:date].present?
    base = base.where(doctor_id: params[:doctor_id])   if params[:doctor_id].present?

    @filter = params[:filter].presence || "all"
    base =
      case @filter
      when "today"            then base.for_today
      when "upcoming"         then base.upcoming.open
      when "open"             then base.open
      when "completed"        then base.completed
      when "cancelled"        then base.cancelled
      when "pending_bookings" then base.where(source: "public_booking", status: "scheduled")
      else base
      end

    @appointments = base.order(appointment_date: :asc, appointment_time: :asc)

    @appointment = current_clinic.appointments.new
    @doctors     = current_clinic.members.where(clinic_members: { role: %w[doctor owner] })
    @patients    = current_clinic.patients.order(:name)

    @counts = {
      all:              current_clinic.appointments.count,
      today:            current_clinic.appointments.for_today.count,
      upcoming:         current_clinic.appointments.upcoming.open.count,
      open:             current_clinic.appointments.open.count,
      completed:        current_clinic.appointments.completed.count,
      cancelled:        current_clinic.appointments.cancelled.count,
      pending_bookings: current_clinic.appointments.where(source: "public_booking", status: "scheduled").count,
    }
  end

  def show
    @report      = @appointment.medical_report || current_clinic.medical_reports.new(appointment: @appointment)
    @medication  = current_clinic.medications.new(appointment: @appointment, patient: @appointment.patient)
    @medications = @appointment.medications
  end

  def new
    @appointment = current_clinic.appointments.new(
      patient_id:       params[:patient_id],
      doctor_id:        params[:doctor_id],
      appointment_date: params[:appointment_date] || Date.current,
      appointment_time: params[:appointment_time],
      reason:           params[:reason],
      duration_minutes: params[:duration_minutes] || 30
    )
    @doctors  = current_clinic.members.where(clinic_members: { role: %w[doctor owner] })
    @patients = current_clinic.patients.order(:name)
  end

  def create
    @appointment = current_clinic.appointments.new(appointment_params)
    @appointment.doctor ||= current_user
    @appointment.status ||= "scheduled"

    if @appointment.save
      redirect_to dashboard_appointments_path, notice: t("appointments.scheduled")
    else
      @doctors      = current_clinic.members.where(clinic_members: { role: %w[doctor owner] })
      @patients     = current_clinic.patients.order(:name)
      @appointments = current_clinic.appointments.includes(:patient, :doctor).order(appointment_date: :asc, appointment_time: :asc)
      @counts = { all: 0, today: 0, upcoming: 0, open: 0, completed: 0, cancelled: 0, pending_bookings: 0 }
      render :index, status: :unprocessable_entity
    end
  end

  # ── Status transitions ────────────────────────────

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
      if params[:next_action] == "prescribe"
        redirect_to dashboard_medications_path(
                      appointment_id: @appointment.id,
                      patient_id:     @appointment.patient_id
                    ),
                    notice: "✓ تم إكمال الزيارة — الآن اكتب الوصفة"
      else
        redirect_to dashboard_appointment_path(@appointment),
                    notice: t("appointments.completed_notice")
      end
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

  # ── Public booking ───────────────────────────────

  def accept_booking
    @appointment.update!(status: "confirmed")

    if @appointment.patient&.email.present?
      begin
        ics_data = IcsGenerator.new(appointment: @appointment).to_ics
        AppointmentMailer.confirmed(@appointment, ics_data).deliver_later
        flash[:notice] = "تم تأكيد الحجز وإرسال دعوة التقويم"
      rescue => e
        Rails.logger.error("ICS email failed: #{e.message}")
        flash[:notice] = "تم تأكيد الحجز"
      end
    else
      flash[:notice] = "تم تأكيد الحجز"
    end

    redirect_to dashboard_appointment_path(@appointment)
  end

  def ics
    ics_data = IcsGenerator.new(appointment: @appointment).to_ics
    send_data ics_data,
              filename: "appointment-#{@appointment.id}.ics",
              type: "text/calendar",
              disposition: "attachment"
  end

  def send_reminder
    patient = @appointment.patient

    # Try email first
    if patient&.email.present?
      begin
        ReminderMailer.appointment_reminder(@appointment).deliver_now
        redirect_to dashboard_appointment_path(@appointment),
                    notice: "✅ تم إرسال التذكير إلى #{patient.email}"
        return
      rescue => e
        Rails.logger.error("Email reminder failed: #{e.message}")
        # Fall through to WhatsApp
      end
    end

    # Try WhatsApp
    if patient&.phone.present?
      begin
        WhatsappBookingNotifier.new(@appointment).send_reminder
        redirect_to dashboard_appointment_path(@appointment),
                    notice: "✅ تم إرسال التذكير عبر واتساب إلى #{patient.phone}"
      rescue => e
        Rails.logger.error("WhatsApp reminder failed: #{e.message}")
        redirect_to dashboard_appointment_path(@appointment),
                    alert: "❌ لا يوجد بريد إلكتروني ولا واتساب متاح للمريض"
      end
    else
      redirect_to dashboard_appointment_path(@appointment),
                  alert: "لا يوجد بريد إلكتروني ولا رقم هاتف للمريض"
    end
  end

  def prescription
    @clinic      = current_clinic
    @medications = @appointment.medications

    begin
      require "rqrcode"
      require "base64"
      require "socket"

      lan_host = ENV["APP_HOST"].presence ||
                 Socket.ip_address_list.find { |ip| ip.ipv4? && !ip.ipv4_loopback? }&.ip_address ||
                 request.host

      qr_url = public_prescription_url(@appointment.public_token, host: lan_host, port: request.port)
      qr = RQRCode::QRCode.new(qr_url)
      svg = qr.as_svg(offset: 0, color: "#0f172a", shape_rendering: "crispEdges", module_size: 4, standalone: true, use_path: true)
      @qr_data_uri = "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
    rescue => e
      Rails.logger.error("QR generation failed: #{e.message}")
      @qr_data_uri = nil
    end

    respond_to do |format|
      format.html { render :prescription, layout: false }
      format.pdf do
        render pdf: "prescription-#{@appointment.id}",
               template: "dashboard/appointments/prescription",
               formats: [:html],
               layout: false,
               encoding: "UTF-8",
               page_size: "A4",
               margin: { top: 15, bottom: 15, left: 10, right: 10 },
               disposition: "inline"
      end
    end
  end

  # ── Visit wizard (guided step-by-step) ───────────

  WIZARD_STEPS = %w[vitals prescription report followup].freeze

  def wizard
    step = params[:step].presence || "vitals"
    step = "vitals" unless WIZARD_STEPS.include?(step)
    @step = step

    @report      = @appointment.medical_report || current_clinic.medical_reports.new(appointment: @appointment)
    @medication  = current_clinic.medications.new(appointment: @appointment, patient: @appointment.patient)
    @medications = @appointment.medications

    render "dashboard/visit_wizard/#{step}"
  end

  def wizard_save
    step   = params[:step].to_s
    action = params[:next_action].to_s

    case step
    when "vitals"
      save_vitals
    when "prescription"
      save_medication unless action == "skip"
    when "report"
      save_report unless action == "skip"
    when "followup"
      save_followup unless action == "skip"
    end

    # Update visit notes if provided on vitals step
    if params[:visit_notes].present?
      @appointment.update(visit_notes: params[:visit_notes])
    end

    case action
    when "close"
      @appointment.complete!(current_user) if @appointment.status == "in_progress"
      redirect_to dashboard_appointment_path(@appointment), notice: "✓ تم إنهاء الزيارة"
    when "skip", "next"
      next_step = WIZARD_STEPS[WIZARD_STEPS.index(step).to_i + 1]
      if next_step
        redirect_to wizard_dashboard_appointment_path(@appointment, step: next_step)
      else
        redirect_to dashboard_appointment_path(@appointment), notice: "✓ تم إنهاء الزيارة"
      end
    else
      redirect_to dashboard_appointment_path(@appointment)
    end
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

  # ── Wizard step savers ───────────────────────────

  def save_vitals
    vitals = params[:vitals].present? ? params[:vitals].to_unsafe_h : {}
    @appointment.update(vitals: vitals) if vitals.present?
  rescue => e
    Rails.logger.error("Vitals save failed: #{e.message}")
  end

  def save_medication
    return unless params[:medication].present?

    attrs = params[:medication].permit(:name, :name_ar, :dosage, :frequency, :duration, :quantity, :instructions)
    return if attrs[:name].blank? && attrs[:name_ar].blank?

    current_clinic.medications.create!(
      attrs.merge(
        appointment: @appointment,
        patient:     @appointment.patient,
        doctor:      current_user,
        status:      "active"
      )
    )
  rescue => e
    Rails.logger.error("Medication save failed: #{e.message}")
  end

  def save_report
    return unless params[:medical_report].present?

    attrs = params[:medical_report].permit(:diagnosis, :treatment, :notes)

    report = @appointment.medical_report || current_clinic.medical_reports.new(appointment: @appointment)
    report.assign_attributes(attrs.merge(patient: @appointment.patient, doctor: current_user))
    report.save
  rescue => e
    Rails.logger.error("Report save failed: #{e.message}")
  end

  def save_followup
    return if params[:followup_date].blank?
    @appointment.update(follow_up_date: params[:followup_date])
  rescue => e
    Rails.logger.error("Followup save failed: #{e.message}")
  end
end
