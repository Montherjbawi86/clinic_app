class Dashboard::MedicationsController < Dashboard::BaseController
  before_action :set_medication, only: [:show, :destroy, :discontinue, :complete, :refill]

  def index
    scope = current_clinic.medications.includes(:patient, :doctor, :appointment).recent

    # Search — single query, no `.or` needed
    if params[:q].present?
      q = "%#{params[:q]}%"
      scope = scope
        .left_joins(:patient)
        .where(
          "medications.name ILIKE :q OR medications.name_ar ILIKE :q OR medications.instructions ILIKE :q " \
          "OR patients.name ILIKE :q OR patients.name_ar ILIKE :q",
          q: q
        )
        .distinct
    end

    # Filter by status
    @filter = params[:filter].presence || "all"
    scope =
      case @filter
      when "active"       then scope.where(status: "active")
      when "completed"    then scope.where(status: "completed")
      when "discontinued" then scope.where(status: "discontinued")
      when "refill_due"   then scope.where(status: "active").where("refills > 0")
      else scope
      end

    # Filter by patient
    scope = scope.where(patient_id: params[:patient_id]) if params[:patient_id].present?

    # Sort
    @sort = params[:sort].presence || "recent"
    scope =
      case @sort
      when "patient" then scope.joins(:patient).reorder(Arel.sql("patients.name ASC"))
      when "oldest"  then scope.reorder(created_at: :asc)
      else scope.reorder(created_at: :desc)
      end

    @medications = scope

    # Stats
    @total_count        = current_clinic.medications.count
    @active_count       = current_clinic.medications.where(status: "active").count
    @completed_count    = current_clinic.medications.where(status: "completed").count
    @discontinued_count = current_clinic.medications.where(status: "discontinued").count
    @refill_due_count   = current_clinic.medications.where(status: "active").where("refills > 0").count

    @medication = current_clinic.medications.new(
      patient_id:     params[:patient_id],
      appointment_id: params[:appointment_id]
    )
    @preselected_patient = current_clinic.patients.find_by(id: params[:patient_id]) if params[:patient_id].present?
    @patients   = current_clinic.patients.order(:name)

    respond_to do |format|
      format.html

      format.csv do
        send_data medications_csv,
                  filename: "medications-#{Date.current}.csv",
                  type: "text/csv; charset=utf-8",
                  disposition: "attachment"
      end

      format.pdf do
        render pdf: "medications-#{Date.current}",
               template: "dashboard/medications/export",
               formats: [:html],
               layout: false,
               encoding: "UTF-8",
               page_size: "A4",
               margin: { top: 15, bottom: 15, left: 10, right: 10 },
               disposition: "inline"
      end
    end
  end

  def show
    @patient = @medication.patient

    # Generate QR data URI — use LAN IP so phones on the same WiFi can reach it
    begin
      require "rqrcode"
      require "base64"
      require "socket"

      lan_host = ENV["APP_HOST"].presence ||
                 Socket.ip_address_list.find { |ip| ip.ipv4? && !ip.ipv4_loopback? }&.ip_address ||
                 request.host

      qr_url = public_medication_url(@medication.public_token, host: lan_host, port: request.port)

      qr = RQRCode::QRCode.new(qr_url)
      svg = qr.as_svg(
        offset: 0,
        color: "0f172a",
        shape_rendering: "crispEdges",
        module_size: 4,
        standalone: true,
        use_path: true
      )
      @qr_data_uri = "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
      @qr_url = qr_url
    rescue => e
      Rails.logger.error("Medication QR failed: #{e.message}")
      @qr_data_uri = nil
      @qr_url = nil
    end
  end

  def create
    @medication = current_clinic.medications.new(medication_params)
    @medication.doctor = current_user

    # Check for allergy conflict
    if allergy_conflict?
      @medication.errors.add(:base, "⚠️ تحذير: المريض لديه حساسية من #{@medication.name}")
      render_index_with_errors and return
    end

    if @medication.save
      redirect_to dashboard_medications_path, notice: "تم وصف الدواء بنجاح."
    else
      render_index_with_errors
    end
  end

  def destroy
    @medication.destroy
    redirect_to dashboard_medications_path, notice: "تم حذف الوصفة."
  end

  def discontinue
    @medication.update!(status: "discontinued")
    redirect_back fallback_location: dashboard_medications_path, notice: "تم إيقاف الوصفة."
  end

  def complete
    @medication.update!(status: "completed")
    redirect_back fallback_location: dashboard_medications_path, notice: "تم إكمال الوصفة."
  end

  def refill
    @medication.update!(refills: (@medication.refills.to_i - 1), status: "active")
    redirect_back fallback_location: dashboard_medications_path, notice: "تم تجديد الوصفة."
  end

  private

  def lan_host
    @lan_host ||= ENV["APP_HOST"].presence ||
                  (begin
                    require "socket"
                    Socket.ip_address_list.find { |ip| ip.ipv4? && !ip.ipv4_loopback? }&.ip_address
                  rescue
                    nil
                  end) ||
                  request.host
  end

  def set_medication
    @medication = current_clinic.medications.find(params[:id])
  end

  def medication_params
    params.require(:medication).permit(
      :patient_id, :appointment_id, :name, :name_ar, :dosage, :frequency,
      :duration, :route, :quantity, :refills, :instructions, :status
    )
  end

  def render_index_with_errors
    @medications = current_clinic.medications.includes(:patient, :doctor).recent
    @patients    = current_clinic.patients.order(:name)
    @total_count = current_clinic.medications.count
    @active_count = current_clinic.medications.where(status: "active").count
    @completed_count = current_clinic.medications.where(status: "completed").count
    @discontinued_count = current_clinic.medications.where(status: "discontinued").count
    @refill_due_count = current_clinic.medications.where(status: "active").where("refills > 0").count
    @filter = "all"
    @sort = "recent"
    render :index, status: :unprocessable_entity
  end

  def allergy_conflict?
    return false if @medication.patient.nil? || @medication.name.blank?
    allergies = @medication.patient.allergies.to_s.downcase
    return false if allergies.blank?
    allergies.include?(@medication.name.downcase)
  end

  def medications_csv
    require "csv"
    CSV.generate(headers: true) do |csv|
      csv << ["ID", "Patient", "Medication", "Dosage", "Frequency", "Duration",
              "Status", "Doctor", "Prescribed"]
      @medications.each do |m|
        csv << [
          m.id, m.patient&.display_name, m.display_name, m.dosage,
          m.frequency, m.duration, m.status, m.doctor&.name,
          m.created_at.strftime("%Y-%m-%d")
        ]
      end
    end
  end
end
