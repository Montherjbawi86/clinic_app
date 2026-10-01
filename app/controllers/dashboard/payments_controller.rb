class Dashboard::PaymentsController < Dashboard::BaseController
  before_action :set_payment, only: [:show, :destroy, :refund, :receipt, :mark_paid, :mark_pending, :refund]

  def index
    scope = current_clinic.payments.includes(:user, :patient).recent

    # Search
    if params[:q].present?
      q = "%#{params[:q]}%"
      scope = scope
        .left_joins(:patient)
        .where(
          "payments.reference ILIKE :q OR payments.notes ILIKE :q " \
          "OR patients.name ILIKE :q OR patients.name_ar ILIKE :q",
          q: q
        )
        .distinct
    end

    # Filter by status
    @filter = params[:filter].presence || "all"
    scope =
      case @filter
      when "paid"     then scope.where(status: "paid")
      when "pending"  then scope.where(status: "pending")
      when "failed"   then scope.where(status: "failed")
      when "refunded" then scope.where(status: "refunded")
      when "today"    then scope.where(created_at: Time.current.all_day)
      when "month"    then scope.where(created_at: Time.current.all_month)
      else scope
      end

    # Filter by patient
    scope = scope.where(patient_id: params[:patient_id]) if params[:patient_id].present?

    # Filter by method
    scope = scope.where(method: params[:method]) if params[:method].present?

    # Date range
    if params[:from].present?
      scope = scope.where("created_at >= ?", Date.parse(params[:from]).beginning_of_day) rescue nil
    end
    if params[:to].present?
      scope = scope.where("created_at <= ?", Date.parse(params[:to]).end_of_day) rescue nil
    end

    # Sort
    @sort = params[:sort].presence || "recent"
    scope =
      case @sort
      when "oldest"     then scope.reorder(created_at: :asc)
      when "highest"    then scope.reorder(amount: :desc)
      when "lowest"     then scope.reorder(amount: :asc)
      else scope.reorder(created_at: :desc)
      end

    @payments = scope

    # Stats
    paid_scope = current_clinic.payments.paid
    @total_paid       = paid_scope.sum(:amount)
    @total_pending    = current_clinic.payments.pending.sum(:amount)
    @month_paid       = paid_scope.where(created_at: Time.current.all_month).sum(:amount)
    @today_paid       = paid_scope.where(created_at: Time.current.all_day).sum(:amount)
    @count_paid       = paid_scope.count
    @average_paid     = @count_paid > 0 ? (@total_paid / @count_paid).round(0) : 0

    # Filter counts
    @counts = {
      all:      current_clinic.payments.count,
      paid:     paid_scope.count,
      pending:  current_clinic.payments.where(status: "pending").count,
      failed:   current_clinic.payments.where(status: "failed").count,
      refunded: current_clinic.payments.where(status: "refunded").count,
      today:    paid_scope.where(created_at: Time.current.all_day).count,
      month:    paid_scope.where(created_at: Time.current.all_month).count
    }

    # Methods breakdown (this month)
    @methods_breakdown = paid_scope
                          .where(created_at: Time.current.all_month)
                          .group(:method)
                          .sum(:amount)

    # Form + patients
    @payment  = current_clinic.payments.new
    @patients = current_clinic.patients.order(:name)

    respond_to do |format|
      format.html
      format.csv  { send_data payments_csv, filename: "payments-#{Date.current}.csv", type: "text/csv; charset=utf-8" }
      format.pdf  do
        render pdf: "payments-#{Date.current}",
               template: "dashboard/payments/export",
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

  def show; end

  def create
    @payment = current_clinic.payments.new(payment_params)
    @payment.user = current_user

    if @payment.save
      redirect_to dashboard_payments_path, notice: "تم تسجيل الدفعة."
    else
      @payments = current_clinic.payments.includes(:user, :patient).recent
      @patients = current_clinic.patients.order(:name)
      load_stats
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @payment.destroy
    redirect_to dashboard_payments_path, notice: "تم حذف الدفعة."
  end

  def refund
    @payment.update!(status: "refunded")
    redirect_back fallback_location: dashboard_payments_path, notice: "تم استرجاع الدفعة."
  end

  def receipt
    render pdf: "receipt-#{@payment.id}",
           template: "dashboard/payments/receipt",
           formats: [:html],
           layout: false,
           encoding: "UTF-8",
           page_size: "A5",
           margin: { top: 10, bottom: 10, left: 10, right: 10 },
           disposition: "inline"
  end


  def mark_paid
    @payment.update!(status: "paid", paid_at: Time.current)
    redirect_back fallback_location: dashboard_payments_path, notice: "✅ تم تحديد الدفعة كمدفوعة."
  end

  def mark_pending
    @payment.update!(status: "pending", paid_at: nil)
    redirect_back fallback_location: dashboard_payments_path, notice: "⏳ تم تحديد الدفعة كمعلّقة."
  end

  def refund
    @payment.update!(status: "refunded")
    redirect_back fallback_location: dashboard_payments_path, notice: "↩️ تم استرجاع الدفعة."
  end

  private

  def set_payment
    @payment = current_clinic.payments.find(params[:id])
  end

  def payment_params
    params.require(:payment).permit(
      :patient_id, :appointment_id, :amount, :currency, :method,
      :status, :reference, :notes, :paid_at
    )
  end

  def load_stats
    paid_scope = current_clinic.payments.paid
    @total_paid       = paid_scope.sum(:amount)
    @total_pending    = current_clinic.payments.pending.sum(:amount)
    @month_paid       = paid_scope.where(created_at: Time.current.all_month).sum(:amount)
    @today_paid       = paid_scope.where(created_at: Time.current.all_day).sum(:amount)
    @count_paid       = paid_scope.count
    @average_paid     = @count_paid > 0 ? (@total_paid / @count_paid).round(0) : 0
    @counts = {
      all:      current_clinic.payments.count,
      paid:     paid_scope.count,
      pending:  current_clinic.payments.where(status: "pending").count,
      failed:   current_clinic.payments.where(status: "failed").count,
      refunded: current_clinic.payments.where(status: "refunded").count,
      today:    paid_scope.where(created_at: Time.current.all_day).count,
      month:    paid_scope.where(created_at: Time.current.all_month).count
    }
    @methods_breakdown = paid_scope.where(created_at: Time.current.all_month).group(:method).sum(:amount)
    @filter = "all"
    @sort   = "recent"
  end

  def payments_csv
    require "csv"
    CSV.generate(headers: true) do |csv|
      csv << ["ID", "Date", "Patient", "Amount", "Currency", "Method", "Status", "Reference", "Recorded By"]
      @payments.each do |p|
        csv << [
          p.id, p.created_at.strftime("%Y-%m-%d %H:%M"),
          p.patient&.display_name, p.amount, p.currency,
          p.method, p.status, p.reference, p.user&.name
        ]
      end
    end
  end
end
