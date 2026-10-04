class AppointmentReminderJob < ApplicationJob
  queue_as :default

  def perform
    tomorrow = Date.current + 1.day

    Rails.logger.info("🔔 Sending reminders for #{tomorrow}")

    # All clinics
    Clinic.find_each do |clinic|
      send_patient_reminders(clinic, tomorrow)
      send_clinic_summary(clinic, tomorrow)
    end

    Rails.logger.info("🔔 Reminders sent")
  end

  private

  def send_patient_reminders(clinic, date)
    appointments = clinic.appointments
                         .includes(:patient, :doctor)
                         .where(appointment_date: date)
                         .where.not(status: %w[cancelled no_show completed])

    appointments.each do |appointment|
      next if appointment.patient&.email.blank?

      begin
        ReminderMailer.appointment_reminder(appointment).deliver_now
        Rails.logger.info("  ✅ Reminder sent → #{appointment.patient.email}")
      rescue => e
        Rails.logger.error("  ❌ Failed for #{appointment.patient.email}: #{e.message}")
      end
    end
  end

  def send_clinic_summary(clinic, date)
    tomorrow_appointments = clinic.appointments
                                  .includes(:patient, :doctor)
                                  .where(appointment_date: date)
                                  .where.not(status: %w[cancelled no_show])

    return if tomorrow_appointments.empty?

    # Send summary to each doctor and owner in the clinic
    recipients = clinic.members.where(clinic_members: { role: %w[doctor owner] })

    recipients.each do |user|
      next if user.email.blank?

      begin
        ReminderMailer.daily_summary(clinic, tomorrow_appointments, user).deliver_now
        Rails.logger.info("  ✅ Daily summary sent → #{user.email}")
      rescue => e
        Rails.logger.error("  ❌ Failed for #{user.email}: #{e.message}")
      end
    end
  end
end
