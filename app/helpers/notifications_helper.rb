module NotificationsHelper
  def notification_link_path(notification)
    case notification.notifiable
    when Subscription
      dashboard_subscriptions_path
    when Appointment
      dashboard_appointment_path(notification.notifiable)
    when Payment
      dashboard_payments_path
    else
      notifications_path
    end
  rescue
    notifications_path
  end

  def notification_title(notification)
    if I18n.locale == :ar && notification.try(:title_ar).present?
      notification.title_ar
    else
      notification.title
    end
  end

  def notification_message(notification)
    if I18n.locale == :ar && notification.try(:message_ar).present?
      notification.message_ar
    else
      notification.message
    end
  end

  def notification_icon(notification)
    case notification.notification_type
    when "payment_due"          then "💳"
    when "appointment_reminder" then "📅"
    when "system"               then "🔔"
    else "🔔"
    end
  end
end
