class Dashboard::PatientsController < Dashboard::BaseController
  before_action :set_patient, only: [:show, :edit, :update, :destroy, :timeline, :qr]

  def index
    scope = current_clinic.patients.order(created_at: :desc)

    # Search
    scope = scope.search(params[:q]) if params[:q].present?

    # Filter
    @filter = params[:filter].presence || "all"
    scope =
      case @filter
      when "recent"     then scope.where("created_at > ?", 30.days.ago)
      when "allergies"  then scope.where("allergies IS NOT NULL AND allergies != ''")
      when "insurance"  then scope.where("insurance_provider IS NOT NULL AND insurance_provider != ''")
      when "chronic"    then scope.where("chronic_conditions IS NOT NULL AND chronic_conditions != ''")
      else scope
      end

    # Sort
    @sort = params[:sort].presence || "newest"
    scope =
      case @sort
      when "name"     then scope.reorder(Arel.sql("COALESCE(name_ar, name) ASC"))
      when "oldest"   then scope.reorder(created_at: :asc)
      when "updated"  then scope.reorder(updated_at: :desc)
      else scope.reorder(created_at: :desc)
      end

    @patients = scope

    # Stats
    @total_count    = current_clinic.patients.count
    @new_month      = current_clinic.patients.where(created_at: Time.current.all_month).count
    @allergies_count = current_clinic.patients.where("allergies IS NOT NULL AND allergies != ''").count
    @insurance_count = current_clinic.patients.where("insurance_provider IS NOT NULL AND insurance_provider != ''").count

    respond_to do |format|
      format.html

      format.csv do
        send_data patients_csv,
                  filename: "patients-#{Date.current}.csv",
                  type: "text/csv; charset=utf-8",
                  disposition: "attachment"
      end

      format.pdf do
        render pdf: "patients-#{Date.current}",
               template: "dashboard/patients/export",
               formats: [:html],
               layout: false,
               encoding: "UTF-8",
               page_size: "A4",
               orientation: "Landscape",
               margin: { top: 15, bottom: 15, left: 10, right: 10 },
               disposition: "inline"
      end
    end
  end

  def show
    # Visit history — group everything by appointment
    @visits = @patient.appointments
                     .includes(:doctor, :medications, :medical_report, :payment)
                     .order(appointment_date: :desc, appointment_time: :desc)

    # Items not linked to an appointment
    @loose_medications = @patient.medications.where(appointment_id: nil).recent
    @loose_reports     = @patient.medical_reports.where(appointment_id: nil).recent.limit(5)
    @loose_payments    = @patient.payments.where(appointment_id: nil).recent.limit(5)

    # Stats
    @visits_count       = @visits.where(status: "completed").count
    @total_paid         = @patient.payments.paid.sum(:amount)
    @balance_due        = @patient.payments.pending.sum(:amount)
    @last_appointment   = @visits.first
    @next_appointment   = @patient.appointments
                                  .where("appointment_date >= ?", Date.current)
                                  .where(status: %w[scheduled confirmed])
                                  .order(:appointment_date, :appointment_time)
                                  .first
    @reports_count      = @patient.medical_reports.count
    @images_count       = @patient.medical_images.count
    @medical_images     = @patient.medical_images.recent.limit(12)
  end

  def qr
    require "rqrcode"
    require "base64"
    require "socket"

    lan_host = ENV["APP_HOST"].presence ||
               Socket.ip_address_list.find { |ip| ip.ipv4? && !ip.ipv4_loopback? }&.ip_address ||
               request.host

    @qr_text = dashboard_patient_url(@patient, host: lan_host, port: request.port)

    qr = RQRCode::QRCode.new(@qr_text)
    svg = qr.as_svg(
      offset: 0,
      color: "#0f172a",
      shape_rendering: "crispEdges",
      module_size: 4,
      standalone: true,
      use_path: true
    )
    @qr_svg = svg.html_safe
  end

  def timeline
    @events = []

    # Build all events
    @patient.appointments.each    { |a| @events << { at: a.created_at, type: "appointment", record: a } }
    @patient.medical_reports.each { |r| @events << { at: r.created_at, type: "report",      record: r } }
    @patient.medications.each     { |m| @events << { at: m.created_at, type: "medication",  record: m } }
    @patient.payments.each        { |p| @events << { at: p.created_at, type: "payment",     record: p } }
    @patient.transfers.each       { |t| @events << { at: t.created_at, type: "transfer",    record: t } }
    @patient.medical_images.each  { |i| @events << { at: i.created_at, type: "image",       record: i } }

    # Filter by type if requested
    if params[:type].present? && params[:type] != "all"
      @events = @events.select { |e| e[:type] == params[:type] }
    end

    # Filter by date range
    if params[:from].present?
      from = Date.parse(params[:from]) rescue nil
      @events = @events.select { |e| e[:at].to_date >= from } if from
    end
    if params[:to].present?
      to = Date.parse(params[:to]) rescue nil
      @events = @events.select { |e| e[:at].to_date <= to } if to
    end

    @events.sort_by! { |e| -e[:at].to_i }

    # Group by month for display
    @events_by_month = @events.group_by { |e| e[:at].strftime("%Y-%m") }

    # Counts per type
    @type_counts = @patient.appointments.count  # placeholder, replaced below
    all_events = []
    @patient.appointments.each    { |a| all_events << "appointment" }
    @patient.medical_reports.each { |r| all_events << "report" }
    @patient.medications.each     { |m| all_events << "medication" }
    @patient.payments.each        { |p| all_events << "payment" }
    @patient.transfers.each       { |t| all_events << "transfer" }
    @patient.medical_images.each  { |i| all_events << "image" }
    @type_counts = all_events.tally

    @current_filter = params[:type].presence || "all"
    @current_from   = params[:from]
    @current_to     = params[:to]
  end

  def new
    @patient = current_clinic.patients.new
  end

  def edit; end

  def create
    @patient = current_clinic.patients.new(patient_params)
    if @patient.save
      redirect_to dashboard_patient_path(@patient), notice: t("patients.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @patient.update(patient_params)
      redirect_to dashboard_patient_path(@patient), notice: t("patients.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @patient.respond_to?(:discard) ? @patient.discard : @patient.destroy
    redirect_to dashboard_patients_path, notice: t("patients.archived")
  end

  private

  def set_patient
    @patient = current_clinic.patients.find(params[:id])
  end

  def patient_params
    params.require(:patient).permit(
      :name, :name_ar, :phone, :gender, :age, :date_of_birth, :medical_history,
      :national_id, :blood_type, :address, :emergency_name, :emergency_phone,
      :allergies, :chronic_conditions, :insurance_provider, :insurance_number,
      :photo
    )
  end

  def patients_csv
    require "csv"
    CSV.generate(headers: true) do |csv|
      csv << ["ID", "Name", "Name (AR)", "Phone", "Gender", "Age", "Blood Type",
              "Allergies", "Chronic Conditions", "Insurance", "Registered"]
      @patients.each do |p|
        csv << [
          p.id, p.name, p.name_ar, p.phone, p.gender, p.age, p.blood_type,
          p.allergies, p.chronic_conditions, p.insurance_provider,
          p.created_at.strftime("%Y-%m-%d")
        ]
      end
    end
  end
end
