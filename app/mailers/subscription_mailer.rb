class SubscriptionMailer < ApplicationMailer
  default from: ENV.fetch("MAILER_FROM", "noreply@clinicapp.sy")

  def confirmed(subscription, user)
    @subscription = subscription
    @user         = user
    @clinic       = subscription.clinic

    mail(
      to:      user.email,
      subject: I18n.locale == :ar ? "تم تفعيل اشتراك عيادتك" : "Your clinic subscription is active"
    )
  end

  def rejected(subscription, user)
    @subscription = subscription
    @user         = user
    @clinic       = subscription.clinic

    mail(
      to:      user.email,
      subject: I18n.locale == :ar ? "تم رفض دفع الاشتراك" : "Subscription payment rejected"
    )
  end
end
