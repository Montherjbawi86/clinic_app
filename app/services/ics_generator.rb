# Generates an .ics (iCalendar) file for an appointment.
# Compatible with Google Calendar, Apple Calendar, Outlook.
class IcsGenerator
  def initialize(appointment:, host: nil)
    @appointment = appointment
    @clinic      = appointment.clinic
    @patient     = appointment.patient
    @doctor      = appointment.doctor
    @host        = host
  end

  def to_ics
    dtstart = parse_datetime(@appointment.appointment_date, @appointment.appointment_time)
    duration = (@appointment.duration_minutes || 30).minutes
    dtend   = dtstart + duration

    lines = []
    lines << "BEGIN:VCALENDAR"
    lines << "VERSION:2.0"
    lines << "PRODID:-//ClinicApp//Appointments//AR"
    lines << "CALSCALE:GREGORIAN"
    lines << "METHOD:REQUEST"
    lines << "BEGIN:VEVENT"
    lines << "UID:appt-#{@appointment.id}@clinicapp"
    lines << "DTSTAMP:#{utc_stamp(Time.current)}"
    lines << "DTSTART:#{utc_stamp(dtstart)}"
    lines << "DTEND:#{utc_stamp(dtend)}"
    lines << "SUMMARY:#{escape("موعد في #{@clinic.display_name}")}"
    lines << "DESCRIPTION:#{escape(description)}"
    lines << "LOCATION:#{escape(location)}"
    lines << "STATUS:CONFIRMED"
    lines << "ORGANIZER;CN=#{escape(@clinic.display_name)}:mailto:#{@clinic.email.presence || "noreply@clinicapp.sy"}"
    lines << "ATTENDEE;CN=#{escape(@patient.display_name)};RSVP=TRUE:mailto:#{@patient.email.presence || "noreply@example.com"}"
    lines << "BEGIN:VALARM"
    lines << "ACTION:DISPLAY"
    lines << "DESCRIPTION:#{escape("تذكير بموعدك")}"
    lines << "TRIGGER:-PT1H"
    lines << "END:VALARM"
    lines << "END:VEVENT"
    lines << "END:VCALENDAR"

    lines.join("\r\n")
  end

  private

  def parse_datetime(date, time_str)
    return Time.current if date.blank?
    t = time_str.presence || "09:00"
    Time.zone.parse("#{date} #{t}") || Time.current
  end

  def utc_stamp(time)
    time.utc.strftime("%Y%m%dT%H%M%SZ")
  end

  def escape(text)
    text.to_s
        .gsub("\\", "\\\\")
        .gsub(",", "\\,")
        .gsub(";", "\\;")
        .gsub("\n", "\\n")
  end

  def description
    parts = []
    parts << "الطبيب: د. #{@doctor&.name}" if @doctor
    parts << "السبب: #{@appointment.reason}" if @appointment.reason.present?
    parts << "رقم الحجز: #{@appointment.booking_ref}" if @appointment.booking_ref.present?
    parts.join("\\n")
  end

  def location
    @clinic.address_display.presence || @clinic.address.to_s
  end
end
