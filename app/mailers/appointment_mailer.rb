class AppointmentMailer < ApplicationMailer
  default from: "ClinicApp <noreply@clinicapp.sy>"

  def confirmed(appointment, ics_data)
    @appointment = appointment
    @clinic      = appointment.clinic
    @patient     = appointment.patient
    @doctor      = appointment.doctor
    @status_url  = public_booking_status_url(
      @clinic.slug,
      ref: appointment.booking_ref,
      host: default_url_host
    )

    ics_filename = "appointment-#{appointment.id}.ics"

    attachments[ics_filename] = {
      mime_type: "text/calendar; method=REQUEST",
      content: ics_data
    }

    mail(
      to: @patient.email,
      subject: "تم تأكيد موعدك — #{@clinic.display_name}"
    )
  end

  private

  def default_url_host
    ENV["APP_HOST"].presence || "127.0.0.1:3000"
  end
end
