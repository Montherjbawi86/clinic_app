class Dashboard::OverviewController < Dashboard::BaseController
  def index
    today = Date.current

    # Top stats
    @stats = {
      today_appointments: current_clinic.appointments.for_today.count,
      checked_in:         current_clinic.appointments.where(appointment_date: today, status: %w[checked_in in_progress]).count,
      reports_today:      current_clinic.medical_reports.where(created_at: Time.current.all_day).count,
      revenue_today:      current_clinic.payments.paid.where(created_at: Time.current.all_day).sum(:amount),
      pending_payments:   current_clinic.payments.pending.sum(:amount),
      new_patients_month: current_clinic.patients.where(created_at: Time.current.all_month).count
    }

    # Today's schedule
    @today_appointments = current_clinic.appointments
                                       .includes(:patient, :doctor)
                                       .for_today
                                       .order(:appointment_time)

    # Follow-ups due (next 14 days)
    @follow_ups = current_clinic.medical_reports
                                .includes(:patient, :doctor)
                                .where(follow_up_date: today..(today + 14.days))
                                .order(:follow_up_date)

    # Recent activity
    @recent_payments = current_clinic.payments.paid.includes(:patient, :user).recent.limit(5)
    @recent_reports  = current_clinic.medical_reports.includes(:patient, :doctor).recent.limit(5)
    @recent_patients = current_clinic.patients.order(created_at: :desc).limit(5)

    # Notifications
    @unread_count = current_user.notifications.unread.count

    # Week ahead
    @week_appointments = current_clinic.appointments
                                       .where(appointment_date: (today + 1.day)..(today + 7.days))
                                       .where.not(status: %w[cancelled no_show])
                                       .count

    # Pending public bookings — need clinic accept/reject
    @pending_bookings = current_clinic.appointments
                                      .where(source: "public_booking", status: "scheduled")
                                      .includes(:patient)
                                      .order(appointment_date: :asc, appointment_time: :asc)
  end
end
