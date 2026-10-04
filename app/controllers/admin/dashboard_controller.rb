class Admin::DashboardController < Admin::BaseController
  def index
    @stats = {
      users:        User.count,
      clinics:      Clinic.count,
      patients:     Patient.count,
      appointments: Appointment.count,
      revenue_mtd:  Payment.paid.where(created_at: Time.current.all_month).sum(:amount),
      plan_counts:  Subscription.group(:plan).count
    }

    @recent_users   = User.order(created_at: :desc).limit(8)
    @recent_clinics = Clinic.order(created_at: :desc).limit(8)
  end
end
