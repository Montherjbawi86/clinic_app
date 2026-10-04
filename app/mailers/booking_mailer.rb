class BookingMailer < ApplicationMailer
  default from: "ClinicApp <noreply@clinicapp.sy>"

  def confirmation(appointment, email)
    @appointment = appointment
    @clinic      = appointment.clinic
    @patient     = appointment.patient
    @status_url  = public_booking_status_url(
      @clinic.slug,
      ref: appointment.booking_ref,
      host: default_url_host
    )

    mail(
      to: email,
      subject: "تأكيد استلام طلب الحجز — #{@clinic.display_name}"
    )
  end

  private

  def default_url_host
    ENV["APP_HOST"].presence || "127.0.0.1:3000"
  end
end
