class Admin::ClinicsController < Admin::BaseController
  before_action :set_clinic, only: [:show, :toggle_public, :deactivate, :activate]

  def index
    scope = Clinic.includes(:owner, :subscriptions).order(created_at: :desc)
    scope = scope.where("name ILIKE :q OR name_ar ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?
    scope = case params[:state]
            when "active"    then scope.kept
            when "suspended" then scope.discarded
            else scope.with_discarded
            end
    @clinics = scope
  end

  def show
    @subscriptions = @clinic.subscriptions.order(created_at: :desc)
  end

  def toggle_public
    @clinic.update(is_public: !@clinic.is_public)
    redirect_back fallback_location: admin_clinic_path(@clinic), notice: "Updated"
  end

  def deactivate
    @clinic.update(discarded_at: Time.current, is_public: false)
    redirect_to admin_clinic_path(@clinic), notice: "Clinic deactivated"
  end

  def activate
    @clinic.update(discarded_at: nil)
    redirect_to admin_clinic_path(@clinic), notice: "Clinic reactivated"
  end

  private

  def set_clinic
    @clinic = Clinic.with_discarded.find(params[:id])
  end
end
