class WhatsappBookingNotifier
  # Sends a WhatsApp message via the browser's click-to-chat URL.
  # No external service needed — the clinic's WhatsApp Business receives it.
  # For automated sending, wire up Twilio or similar later.

  def initialize(appointment)
    @appointment = appointment
    @clinic      = appointment.clinic
    @patient     = appointment.patient
  end

  def send_confirmation
    phone = normalize_phone(@patient.phone)
    return false if phone.blank?

    message = build_message
    # Store the pre-filled click-to-chat URL so the success page can offer a link
    @appointment.update_column(
      :notes,
      [@appointment.notes, "WA: #{whatsapp_url(phone, message)}"].compact.join("\n")
    )

    true
  rescue => e
    Rails.logger.error("WhatsApp notifier failed: #{e.message}")
    false
  end

  # Returns the click-to-chat URL for the given phone/message
  def whatsapp_url(phone, message)
    "https://wa.me/#{phone}?text=#{CGI.escape(message)}"
  end

  private

  def normalize_phone(phone)
    return nil if phone.blank?
    # Strip non-digits, add country code if Syrian number
    digits = phone.gsub(/\D/, "")
    return digits if digits.start_with?("963")
    return "963#{digits.sub(/^0/, "")}" if digits.start_with?("0")
    digits
  end

  def build_message
    url = public_booking_status_url(
      @clinic.slug,
      ref: @appointment.booking_ref,
      host: ENV["APP_HOST"].presence || "127.0.0.1:3000"
    )

    <<~MSG
      🏥 *#{@clinic.display_name}*

      مرحباً #{@patient.display_name}!
      تم استلام طلب حجزك:

      📅 التاريخ: #{@appointment.appointment_date}
      🕐 الوقت: #{@appointment.appointment_time&.strftime("%H:%M")}
      🔖 رقم الحجز: #{@appointment.booking_ref}

      🔍 تابع حالة حجزك:
      #{url}
    MSG
  end
end
