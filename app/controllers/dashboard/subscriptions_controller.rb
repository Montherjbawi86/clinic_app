class Dashboard::SubscriptionsController < Dashboard::BaseController
  def index
    @subscriptions = current_clinic.subscriptions.order(created_at: :desc)
    @current       = current_clinic.subscriptions.active.first ||
                     current_clinic.subscriptions.first ||
                     Subscription.new(plan: "free", status: "active")
    @plans         = Subscription::PLANS
    @limits        = @current.limits

    @usage = {
      patients:   current_clinic.patients.count,
      members:    current_clinic.clinic_members.count,
      clinics:    current_user.clinics.count,
      storage_mb: calculate_storage_mb
    }
  end

  def checkout
    plan = params[:plan].to_s
    unless Subscription::PLANS.include?(plan) && plan != "free"
      return redirect_to dashboard_subscriptions_path, alert: "Invalid plan"
    end

    @plan  = plan
    @price = Subscription::PRICES[plan]
    @subscription = current_clinic.subscriptions.pending_payment.first ||
                    current_clinic.subscriptions.new(plan: plan)
  end

  def submit_payment
    plan = params[:plan].to_s
    unless Subscription::PLANS.include?(plan)
      return redirect_to dashboard_subscriptions_path, alert: "Invalid plan"
    end

    subscription = current_clinic.subscriptions.new(
      plan:                  plan,
      status:                "pending_payment",
      payment_method:        params[:payment_method],
      transaction_reference: params[:transaction_reference],
      payment_proof_note:    params[:payment_proof_note],
      submitted_at:          Time.current
    )

    if params[:payment_proof].present?
      subscription.payment_proof.attach(params[:payment_proof])
    end

    if subscription.save
      User.where(role: "super_admin").find_each do |admin|
        Notification.create!(
          user:              admin,
          notifiable:        subscription,
          notification_type: "payment_due",
          title:             "New subscription request",
          title_ar:          "طلب اشتراك جديد",
          message:           "#{current_clinic.display_name} — plan #{plan} — awaiting review",
          message_ar:        "#{current_clinic.display_name} — خطة #{plan} — ينتظر المراجعة",
          severity:          "warning"
        )
      end

      redirect_to dashboard_subscriptions_path,
                  notice: "Payment proof submitted — subscription will be activated after review"
    else
      redirect_to checkout_dashboard_subscriptions_path(plan: plan),
                  alert: subscription.errors.full_messages.to_sentence
    end
  end

  def upgrade
    plan = params[:plan].to_s
    if plan == "free"
      sub = current_clinic.subscriptions.active.first || current_clinic.subscriptions.new
      sub.update!(plan: "free", status: "active", expires_at: 1.year.from_now)
      return redirect_to dashboard_subscriptions_path, notice: "Free plan activated"
    end

    redirect_to checkout_dashboard_subscriptions_path(plan: plan)
  end

  private

  def calculate_storage_mb
    total = ActiveStorage::Blob
              .joins(:attachments)
              .where(active_storage_attachments: {
                record_type: "MedicalImage",
                record_id:   current_clinic.medical_images.select(:id)
              })
              .sum(:byte_size)
    (total.to_f / 1.megabyte).round(1)
  rescue
    0
  end
end
