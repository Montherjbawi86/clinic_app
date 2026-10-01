class Availability
  # Availability.new(clinic: c, date: Date.current, doctor: user).slots
  # => [{ time: "09:00", status: :free | :booked | :break, appointment: nil|Appointment }, ...]

  def initialize(clinic:, date:, doctor: nil)
    @clinic = clinic
    @date   = date
    @doctor = doctor
  end

  def slots
    return [] unless working_hours_present?

    result   = []
    slot_min = (@clinic.slot_duration_minutes.to_i.clamp(5, 120))

    open_time  = parse_time(day_hours["open"])
    close_time = parse_time(day_hours["close"])
    return [] if open_time.nil? || close_time.nil?

    break_start = parse_time(@clinic.lunch_break_start)
    break_end   = parse_time(@clinic.lunch_break_end)

    booked = @clinic.appointments
                    .where(appointment_date: @date)
                    .where.not(status: %w[cancelled no_show])
    booked = booked.where(doctor: @doctor) if @doctor
    booked = booked.includes(:patient, :doctor).to_a

    current = open_time
    while current + slot_min.minutes <= close_time
      slot_end = current + slot_min.minutes

      in_break = break_start && break_end && current >= break_start && current < break_end

      appointment = booked.find do |a|
        a_start = parse_time(a.appointment_time)
        next false unless a_start
        a_end = a_start + (a.duration_minutes || slot_min).minutes
        a_start < slot_end && a_end > current
      end

      status =
        if in_break       then :break
        elsif appointment then :booked
        else                   :free
        end

      result << {
        time:        current.strftime("%H:%M"),
        time_obj:    current,
        status:      status,
        appointment: appointment
      }

      current = slot_end
    end

    result
  end

  def free_slots_count
    slots.count { |s| s[:status] == :free }
  end

  private

  def working_hours_present?
    day_hours.present? && day_hours["open"].present? && day_hours["close"].present?
  end

  def day_hours
    day_name = @date.strftime("%A").downcase
    (@clinic.working_hours || {})[day_name] || {}
  end

  def parse_time(str)
    return nil if str.blank?
    parts = str.to_s.split(":")
    return nil unless parts.size >= 2
    Time.zone.parse("#{@date} #{parts[0].rjust(2, '0')}:#{parts[1].rjust(2, '0')}")
  rescue
    nil
  end
end
