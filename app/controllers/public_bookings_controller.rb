class PublicBookingsController < ApplicationController
  layout "public"

  def new
    @clinic = Clinic.find_by!(slug: params[:slug])
    @booking = {
      name:  params[:name],
      phone: params[:phone],
      email: params[:email],
      date:  params[:date],
      reason: params[:reason]
    }
  rescue ActiveRecord::RecordNotFound
    render plain: "العيادة غير موجودة", status: :not_found
  end

  def create
    @clinic = Clinic.find_by!(slug: params[:slug])

    name   = params[:name].to_s.strip
    phone  = params[:phone].to_s.strip
    email  = params[:email].to_s.strip.downcase
    date   = params[:date].presence
    time   = params[:time].presence
    reason = params[:reason].to_s.strip

    if name.blank? || phone.blank?
      redirect_to new_public_booking_path(@clinic.slug),
                  alert: "الرجاء إدخال الاسم ورقم الهاتف"
      return
    end

    # Find or create patient by phone
    patient = @clinic.patients.find_by(phone: phone)

    if patient.nil?
      patient = @clinic.patients.create!(
        name:  name,
        name_ar: name,
        phone: phone,
        email: email.presence,
        medical_history: "مريض جديد من الحجز العام"
      )
    elsif email.present? && patient.email.blank?
      # Update email if missing
      patient.update_column(:email, email)
    end

    appointment = @clinic.appointments.new(
      patient: patient,
      doctor: @clinic.owner,
      appointment_date: date.presence || Date.current + 1.day,
      appointment_time: time.presence || "10:00",
      duration_minutes: 30,
      reason: reason.presence || "حجز من الموقع",
      status: "scheduled",
      source: "public_booking"
    )

    if appointment.save
      # Notify clinic owner
      Notification.create!(
        user: @clinic.owner,
        notification_type: "appointment_reminder",
        title: "طلب حجز جديد",
        title_ar: "طلب حجز جديد",
        message: "#{name} طلب موعد على #{appointment.appointment_date} — #{phone}",
        severity: "info"
      )

      # Send confirmation email if email provided
      if email.present?
        begin
          begin
            if Rails.env.development?
              BookingMailer.confirmation(appointment, email).deliver_now
            else
              BookingMailer.confirmation(appointment, email).deliver_later
            end
          rescue => e
            Rails.logger.error("Email enqueue failed: #{e.message}")
          end
          Rails.logger.info("📧 Booking confirmation email queued for #{email}")
        rescue => e
          Rails.logger.error("📧 Email failed: #{e.message}")
        end
      end

      # Send WhatsApp if phone provided
      begin
        WhatsappBookingNotifier.new(appointment).send_confirmation
        Rails.logger.info("💬 WhatsApp notification sent to #{phone}")
      rescue => e
        Rails.logger.error("💬 WhatsApp failed: #{e.message}")
      end

      redirect_to public_booking_success_path(@clinic.slug, appointment_id: appointment.id)
    else
      redirect_to new_public_booking_path(@clinic.slug),
                  alert: appointment.errors.full_messages.to_sentence
    end
  rescue ActiveRecord::RecordNotFound
    render plain: "العيادة غير موجودة", status: :not_found
  end

  def success
    @clinic = Clinic.find_by!(slug: params[:slug])
    @appointment = @clinic.appointments.find_by(id: params[:appointment_id])
  rescue ActiveRecord::RecordNotFound
    render plain: "العيادة غير موجودة", status: :not_found
  end

  def status
    @clinic = Clinic.find_by!(slug: params[:slug])
    ref = params[:ref].to_s.strip.upcase
    @appointment = @clinic.appointments.find_by(booking_ref: ref) if ref.present?
  rescue ActiveRecord::RecordNotFound
    render plain: "العيادة غير موجودة", status: :not_found
  end
end
