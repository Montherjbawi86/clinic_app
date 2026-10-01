class Dashboard::ClinicsController < Dashboard::BaseController
  before_action :set_clinic, only: [:show, :edit, :update, :add_member, :remove_member]

  def index
    @clinics = current_user.clinics.includes(:owner).order(:name)
    @clinic  = Clinic.new
  end

  def show
    @members = @clinic.clinic_members.includes(:user)
    @stats = {
      patients:          @clinic.patients.count,
      appointments:      @clinic.appointments.count,
      today_appointments: @clinic.appointments.for_today.count,
      reports:           @clinic.medical_reports.count,
      revenue_month:     @clinic.payments.paid.where(created_at: Time.current.all_month).sum(:amount),
      pending_payments:  @clinic.payments.pending.sum(:amount)
    }
    @recent_activity = @clinic.appointments.includes(:patient, :doctor).order(created_at: :desc).limit(5)
  end

  def new
    @clinic = Clinic.new
  end

  def create
    @clinic = Clinic.new(clinic_params)
    @clinic.owner = current_user

    if @clinic.save
      ClinicMember.find_or_create_by!(clinic: @clinic, user: current_user) { |m| m.role = "owner" }
      redirect_to dashboard_clinic_path(@clinic), notice: "تم إنشاء العيادة."
    else
      @clinics = current_user.clinics
      render :index, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @clinic.update(clinic_params)
      redirect_to dashboard_clinic_path(@clinic), notice: "تم تحديث بيانات العيادة."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def add_member
    user = User.find_by(email: params[:email].to_s.downcase.strip)
    if user.nil?
      redirect_to dashboard_clinic_path(@clinic), alert: "لا يوجد مستخدم بهذا البريد."
      return
    end

    member = @clinic.clinic_members.find_or_initialize_by(user: user)
    member.role = params[:role].presence || "doctor"

    if member.save
      redirect_to dashboard_clinic_path(@clinic), notice: "تم إضافة العضو."
    else
      redirect_to dashboard_clinic_path(@clinic), alert: member.errors.full_messages.to_sentence
    end
  end

  def remove_member
    member = @clinic.clinic_members.find(params[:member_id])

    if member.role == "owner"
      redirect_to dashboard_clinic_path(@clinic), alert: "لا يمكن إزالة المالك."
      return
    end

    member.destroy
    redirect_to dashboard_clinic_path(@clinic), notice: "تم إزالة العضو."
  end

  private

  def set_clinic
    @clinic = current_user.clinics.find(params[:id])
  end

  def clinic_params
    params.require(:clinic).permit(
      :name, :name_ar, :address, :address_ar, :phone, :email,
      :city, :specialty, :about, :about_ar, :is_public, :logo,
      working_hours: {}
    )
  end
end
