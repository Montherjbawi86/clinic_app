class Dashboard::ReportsController < Dashboard::BaseController
  before_action :set_report, only: [:show, :destroy]

  def index
    scope = current_clinic.medical_reports.includes(:patient, :doctor, :appointment).recent

    # Search
    if params[:q].present?
      q = "%#{params[:q]}%"
      scope = scope
        .left_joins(:patient)
        .where(
          "medical_reports.diagnosis ILIKE :q OR medical_reports.diagnosis_ar ILIKE :q " \
          "OR medical_reports.treatment ILIKE :q OR medical_reports.treatment_ar ILIKE :q " \
          "OR patients.name ILIKE :q OR patients.name_ar ILIKE :q",
          q: q
        )
        .distinct
    end

    # Filters
    @filter = params[:filter].presence || "all"
    scope =
      case @filter
      when "month"      then scope.where(created_at: Time.current.all_month)
      when "follow_up"  then scope.where.not(follow_up_date: nil).where("follow_up_date >= ?", Date.current)
      when "today"      then scope.where(created_at: Time.current.all_day)
      else scope
      end

    # Sort
    @sort = params[:sort].presence || "recent"
    scope =
      case @sort
      when "oldest"   then scope.reorder(created_at: :asc)
      when "patient"  then scope.joins(:patient).reorder(Arel.sql("patients.name ASC"))
      else scope.reorder(created_at: :desc)
      end

    @reports = scope

    # Stats
    @total_count       = current_clinic.medical_reports.count
    @month_count       = current_clinic.medical_reports.where(created_at: Time.current.all_month).count
    @today_count       = current_clinic.medical_reports.where(created_at: Time.current.all_day).count
    @follow_up_count   = current_clinic.medical_reports
                                       .where.not(follow_up_date: nil)
                                       .where("follow_up_date >= ?", Date.current)
                                       .count
    @unique_patients   = current_clinic.medical_reports.distinct.count(:patient_id)

    # Form
    @report = current_clinic.medical_reports.new(
      patient_id:     params[:patient_id],
      appointment_id: params[:appointment_id]
    )
    @patients     = current_clinic.patients.order(:name)
    @appointments = current_clinic.appointments.upcoming

    respond_to do |format|
      format.html
      format.csv  do
        send_data reports_csv,
                  filename: "reports-#{Date.current}.csv",
                  type: "text/csv; charset=utf-8",
                  disposition: "attachment"
      end
      format.pdf do
        render pdf: "reports-#{Date.current}",
               template: "dashboard/reports/export",
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
    @patient     = @report.patient
    @doctor      = @report.doctor
    @appointment = @report.appointment
    @medications = @appointment&.medications || []
    @report_qr   = generate_qr(@report)

    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "report-#{@report.id}",
               template: "dashboard/reports/report_pdf",
               formats: [:html],
               layout: false,
               encoding: "UTF-8",
               page_size: "A4",
               margin: { top: 15, bottom: 15, left: 12, right: 12 },
               disposition: "inline"
      end
    end
  end

  def create
    @report = current_clinic.medical_reports.new(report_params)
    @report.doctor = current_user

    if @report.save
      redirect_to dashboard_report_path(@report), notice: "تم إضافة التقرير بنجاح."
    else
      @reports = current_clinic.medical_reports.includes(:patient, :doctor).recent
      @patients = current_clinic.patients.order(:name)
      @appointments = current_clinic.appointments.upcoming
      @total_count = current_clinic.medical_reports.count
      @month_count = current_clinic.medical_reports.where(created_at: Time.current.all_month).count
      @today_count = current_clinic.medical_reports.where(created_at: Time.current.all_day).count
      @follow_up_count = 0
      @unique_patients = 0
      @filter = "all"
      @sort = "recent"
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @report.destroy
    redirect_to dashboard_reports_path, notice: "تم حذف التقرير."
  end

  private

  def set_report
    @report = current_clinic.medical_reports.find(params[:id])
  end

  def report_params
    params.require(:medical_report).permit(
      :patient_id, :appointment_id, :diagnosis, :diagnosis_ar,
      :treatment, :treatment_ar, :notes, :notes_ar, :follow_up_date, :status
    )
  end

  def generate_qr(report)
    return nil unless report.respond_to?(:public_token) && report.public_token.present?

    require "rqrcode"
    require "base64"
    require "socket"

    lan_host = ENV["APP_HOST"].presence ||
               Socket.ip_address_list.find { |ip| ip.ipv4? && !ip.ipv4_loopback? }&.ip_address ||
               request.host

    url = public_report_url(report.public_token, host: lan_host, port: request.port)
    qr = RQRCode::QRCode.new(url)
    svg = qr.as_svg(offset: 0, color: "0f172a", shape_rendering: "crispEdges", module_size: 4, standalone: true, use_path: true)
    "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
  rescue => e
    Rails.logger.error("Report QR failed: #{e.message}")
    nil
  end

  def reports_csv
    require "csv"
    CSV.generate(headers: true) do |csv|
      csv << ["ID", "Date", "Patient", "Doctor", "Diagnosis", "Treatment", "Follow-up"]
      @reports.each do |r|
        csv << [
          r.id, r.created_at.strftime("%Y-%m-%d"),
          r.patient&.display_name, r.doctor&.name,
          r.diagnosis, r.treatment, r.follow_up_date
        ]
      end
    end
  end
end
