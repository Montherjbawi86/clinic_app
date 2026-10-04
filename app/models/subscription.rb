class Subscription < ApplicationRecord
  PLANS    = %w[free basic pro enterprise].freeze
  STATUSES = %w[active trialing past_due cancelled expired pending_payment rejected].freeze

  LIMITS = {
    "free"       => { patients: 50,      members: 2,  clinics: 1,  storage_mb: 100 },
    "basic"      => { patients: 500,     members: 5,  clinics: 3,  storage_mb: 1_000 },
    "pro"        => { patients: nil,     members: 20, clinics: nil, storage_mb: 10_000 },
    "enterprise" => { patients: nil,     members: nil, clinics: nil, storage_mb: nil }
  }.freeze

  PRICES = {
    "free" => 0, "basic" => 50_000, "pro" => 150_000, "enterprise" => nil
  }.freeze

  PAYMENT_METHODS = %w[sham_cash bank_transfer cash al_haram syriatel_cash].freeze

  belongs_to :clinic
  belongs_to :confirmed_by, class_name: "User", optional: true

  has_one_attached :payment_proof

  validates :plan,   inclusion: { in: PLANS },    allow_nil: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  scope :active,          -> { where(status: "active").where("expires_at > ?", Time.current) }
  scope :pending_payment, -> { where(status: "pending_payment").order(submitted_at: :desc) }
  scope :current,         -> { where(status: %w[active trialing]).order(created_at: :desc).first }

  def active?
    status == "active" && expires_at&.future?
  end

  def pending_payment?
    status == "pending_payment"
  end

  def limits
    LIMITS[plan] || LIMITS["free"]
  end

  def within_limit?(resource, current_count)
    limit = limits[resource.to_sym]
    return true if limit.nil?
    current_count < limit
  end

  def confirm!(admin_user)
    update!(
      status:       "active",
      expires_at:   30.days.from_now,
      confirmed_at: Time.current,
      confirmed_by: admin_user
    )

    notify_clinic(
      title_en:   "Subscription activated",
      title_ar:   "تم تفعيل الاشتراك",
      message_en: "Your #{plan.titleize} plan is now active. Expires #{expires_at.strftime('%Y-%m-%d')}.",
      message_ar: "تم تفعيل خطة #{plan.titleize}. تنتهي في #{expires_at.strftime('%Y-%m-%d')}.",
      severity:   "success"
    )
  end

  def reject!
    update!(status: "rejected")

    notify_clinic(
      title_en:   "Subscription payment rejected",
      title_ar:   "تم رفض دفع الاشتراك",
      message_en: "We could not verify your #{plan.titleize} payment. Please re-submit or contact support.",
      message_ar: "لم نتمكن من التحقق من دفعة خطة #{plan.titleize}. يرجى إعادة الإرسال أو التواصل مع الدعم.",
      severity:   "warning"
    )
  end

  private

  def notify_clinic(title_en:, title_ar:, message_en:, message_ar:, severity:)
    return if clinic.nil?

    recipients = clinic.members.to_a
    recipients << clinic.owner if clinic.owner && !recipients.include?(clinic.owner)
    recipients.compact.uniq.each do |user|
      Notification.create!(
        user:              user,
        notifiable:        self,
        notification_type: "system",
        title:             title_en,
        title_ar:          title_ar,
        message:           message_en,
        message_ar:        message_ar,
        severity:          severity
      )

      if user.email.present?
        if severity == "success"
          SubscriptionMailer.confirmed(self, user).deliver_later
        elsif severity == "warning"
          SubscriptionMailer.rejected(self, user).deliver_later
        end
      end
    end
  rescue => e
    Rails.logger.error("Subscription notification failed: #{e.message}")
  end
end
