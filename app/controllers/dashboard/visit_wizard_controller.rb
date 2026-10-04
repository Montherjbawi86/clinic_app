class Dashboard::VisitWizardController < Dashboard::BaseController
  before_action :set_appointment
  before_action :set_step

  STEPS = %w[vitals prescription report followup].freeze

  # GET /dashboard/appointments/:appointment_id/wizard
  # Optional ?step=prescription to jump to a specific step
  def show
    @step = params[:step].presence || session_step || "vitals"

    unless STEPS.include?(@step)
      @step = "vitals"
    end

    # Load data for the current step
    case @step
    when "vitals"
      # nothing special
    when "prescription"
      @medication = current_clinic.medications.new(appointment: @appointment, patient: @appointment.patient)
      @medications = @appointment.medications
    when "report"
      @report = current_clinic.medical_reports.new(appointment: @appointment, patient: @appointment.patient)
    when "followup"
      # nothing special
    end

    session[:visit_step] = @step
    render "dashboard/visit_wizard/#{@step}"
  end

  # POST /dashboard/appointments/:appointment_id/wizard/save
  def save
    action = params[:next_action]  # "next", "skip", "close"

    case params[:step]
    when "vitals"
      @appointment.complete!(current_user,
                             notes: params[:visit_notes],
                             notes_ar: params[:visit_notes_ar],
                             vitals: params[:vitals],
                             follow_up_date: params[:follow_up_date])
    when "prescription"
      save_prescription if action != "skip" && params[:medication].present?
    when "report"
      save_report if action != "skip" && params[:medical_report].present?
    when "followup"
      save_followup if action != "skip" && params[:followup_date].present?
    end

    case action
    when "close"
      session.delete(:visit_step)
      redirect_to dashboard_appointment_path(@appointment), notice: "✅ تم إكمال الزيارة"
    when "skip", "next"
      next_step = next_step_after(params[:step])
      if next_step.nil?
        session.delete(:visit_step)
        redirect_to dashboard_appointment_path(@appointment), notice: "✅ تم إكمال الزيارة"
      else
        redirect_to wizard_dashboard_appointment_path(@appointment, step: next_step)
      end
    else
      redirect_to wizard_dashboard_appointment_path(@appointment, step: params[:step])
    end
  end

  private

  def set_appointment
    @appointment = current_clinic.appointments.find(params[:appointment_id])
  end

  def set_step
    @step = params[:step]
  end

  def session_step
    session[:visit_step]
  end

  def next_step_after(current)
    idx = STEPS.index(current)
    STEPS[idx + 1]
  end

  def save_prescription
    m = current_clinic.medications.new(medication_params)
    m.doctor = current_user
    m.patient = @appointment.patient
    m.appointment = @appointment
    m.save
  end

  def save_report
    r = current_clinic.medical_reports.new(report_params)
    r.doctor = current_user
    r.patient = @appointment.patient
    r.appointment = @appointment
    r.save
  end

  def save_followup
    @appointment.update(follow_up_date: params[:followup_date])
  end

  def medication_params
    params.require(:medication).permit(:name, :name_ar, :dosage, :frequency, :duration, :route, :instructions, :quantity, :refills)
  end

  def report_params
    params.require(:medical_report).permit(:diagnosis, :diagnosis_ar, :treatment, :treatment_ar, :notes, :notes_ar)
  end
end
