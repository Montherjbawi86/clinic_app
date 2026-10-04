class ReminderMailer < ApplicationMailer
  default from: "ClinicApp <noreply@clinicapp.sy>"

  # Sent to the PATIENT — reminds them of tomorrow's appointment
  def appointment_reminder(appointment)
    @appointment = appointment
    @clinic      = appointment.clinic
    @patient     = appointment.patient
    @doctor      = appointment.doctor

    @status_url = public_booking_status_url(
      @clinic.slug,
      ref: appointment.booking_ref,
      host: default_url_host
    )

    mail(
      to: @patient.email,
      subject: "⏰ تذكير: موعدك غداً في #{@clinic.display_name}"
    )
  end

  # Sent to the CLINIC — daily summary of tomorrow's appointments
  def daily_summary(clinic, appointments, user)
    @clinic       = clinic
    @appointments = appointments
    @user         = user
    @date         = Date.current + 1.day

    mail(
      to: user.email,
      subject: "📅 جدول الغد — #{appointments.count} موعد في #{clinic.display_name}"
    )
  end

  private

  def default_url_host
    ENV["APP_HOST"].presence || "127.0.0.1:3000"
  end
end
