module AppointmentsHelper
  # Works whether the value is a String ("04:39"), Time, or ActiveSupport::TimeWithZone
  def format_time(value, fmt = "%H:%M")
    return "" if value.blank?

    if value.is_a?(String)
      parts = value.split(":")
      return value unless parts.size >= 2
      format("%02d:%02d", parts[0].to_i, parts[1].to_i)
    else
      value.strftime(fmt)
    end
  end
end
