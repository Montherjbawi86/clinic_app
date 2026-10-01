#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Rewriting models…"

cat > app/models/user.rb <<'RUBY'
class User < ApplicationRecord
  has_secure_password

  ROLES   = %w[super_admin owner doctor nurse receptionist accountant].freeze
  LOCALES = %w[ar en].freeze

  has_many :owned_clinics, class_name: "Clinic", foreign_key: "user_id", dependent: :destroy
  has_many :clinic_members, dependent: :destroy
  has_many :clinics, through: :clinic_members

  has_many :doctor_appointments, class_name: "Appointment",
           foreign_key: "doctor_id", dependent: :nullify
  has_many :payments, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :chat_messages, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role,   inclusion: { in: ROLES },   allow_nil: true
  validates :locale, inclusion: { in: LOCALES }, allow_nil: true

  before_validation { self.email = email.to_s.downcase.strip }

  def member_of?(clinic)
    return false unless clinic
    clinic_members.exists?(clinic_id: clinic.id)
  end

  def role_in(clinic)
    clinic_members.find_by(clinic_id: clinic.id)&.role
  end

  def doctor?;      role == "doctor";      end
  def owner?;       role == "owner";       end
  def super_admin?; role == "super_admin"; end
end
RUBY

cat > app/models/clinic.rb <<'RUBY'
class Clinic < ApplicationRecord
  belongs_to :owner, class_name: "User", foreign_key: "user_id"

  has_many :clinic_members, dependent: :destroy
  has_many :members, through: :clinic_members, source: :user
  has_many :patients, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :medical_reports, dependent: :destroy
  has_many :medications, dependent: :destroy
  has_many :transfers, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :subscriptions, dependent: :destroy

  validates :name, presence: true

  def display_name
    name_ar.presence || name
  end

  def address_display
    address_ar.presence || address
  end
end
RUBY

cat > app/models/clinic_member.rb <<'RUBY'
class ClinicMember < ApplicationRecord
  ROLES = %w[owner doctor nurse receptionist accountant].freeze

  belongs_to :clinic
  belongs_to :user

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :clinic_id, message: "already a member of this clinic" }
end
RUBY

cat > app/models/patient.rb <<'RUBY'
class Patient < ApplicationRecord
  belongs_to :clinic
  has_many :appointments,    dependent: :destroy
  has_many :medical_reports, dependent: :destroy
  has_many :medications,     dependent: :destroy
  has_many :transfers,       dependent: :destroy
  has_many :payments,        dependent: :destroy

  validates :name, presence: true
  validates :gender, inclusion: { in: %w[male female] }, allow_nil: true
  validates :age, numericality: { only_integer: true, in: 0..130 }, allow_nil: true

  scope :search, ->(q) {
    where("name ILIKE :q OR name_ar ILIKE :q OR phone ILIKE :q OR national_id ILIKE :q",
          q: "%#{q}%")
  }

  def display_name
    name_ar.presence || name
  end

  def age_from_dob
    return nil unless date_of_birth
    ((Date.current - date_of_birth) / 365.25).floor
  end

  def total_paid
    payments.where(status: "paid").sum(:amount)
  end

  def outstanding_balance
    payments.where(status: "pending").sum(:amount)
  end
end
RUBY

cat > app/models/appointment.rb <<'RUBY'
class Appointment < ApplicationRecord
  STATUSES = %w[scheduled confirmed checked_in completed cancelled no_show].freeze

  belongs_to :clinic
  belongs_to :patient
  belongs_to :doctor, class_name: "User", optional: true

  has_one  :medical_report, dependent: :nullify
  has_many :medications,    dependent: :nullify
  has_one  :payment,        dependent: :nullify

  validates :appointment_date, presence: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  validate :patient_belongs_to_clinic
  validate :doctor_is_clinic_member

  before_validation :default_status
  before_validation :default_duration

  scope :upcoming, -> { where("appointment_date >= ?", Date.current).order(:appointment_date, :appointment_time) }
  scope :for_today, -> { where(appointment_date: Date.current) }
  scope :recent, -> { order(appointment_date: :desc, appointment_time: :desc) }

  def starts_at
    return nil unless appointment_date && appointment_time
    Time.zone.parse("#{appointment_date} #{appointment_time}")
  end

  def ends_at
    starts_at&.+((duration_minutes || 30).minutes)
  end

  private

  def default_status
    self.status ||= "scheduled"
  end

  def default_duration
    self.duration_minutes ||= 30
  end

  def patient_belongs_to_clinic
    return if patient.nil? || clinic.nil?
    errors.add(:patient, "does not belong to this clinic") if patient.clinic_id != clinic_id
  end

  def doctor_is_clinic_member
    return if doctor.nil? || clinic.nil?
    errors.add(:doctor, "is not a member of this clinic") unless doctor.member_of?(clinic)
  end
end
RUBY

cat > app/models/medical_report.rb <<'RUBY'
class MedicalReport < ApplicationRecord
  STATUSES = %w[draft final amended].freeze

  belongs_to :clinic
  belongs_to :patient
  belongs_to :doctor, class_name: "User"
  belongs_to :appointment, optional: true

  validates :diagnosis, presence: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  validate :patient_in_clinic
  validate :doctor_in_clinic

  before_validation :default_status

  scope :recent, -> { order(created_at: :desc) }

  def display_diagnosis
    diagnosis_ar.presence || diagnosis
  end

  def display_treatment
    treatment_ar.presence || treatment
  end

  private

  def default_status
    self.status ||= "final"
  end

  def patient_in_clinic
    return if patient.nil? || clinic.nil?
    errors.add(:patient, "not in this clinic") if patient.clinic_id != clinic_id
  end

  def doctor_in_clinic
    return if doctor.nil? || clinic.nil?
    errors.add(:doctor, "not in this clinic") unless doctor.member_of?(clinic)
  end
end
RUBY

cat > app/models/medication.rb <<'RUBY'
class Medication < ApplicationRecord
  STATUSES = %w[active completed discontinued].freeze
  ROUTES   = %w[oral topical injection inhalation sublingual rectal].freeze

  belongs_to :clinic
  belongs_to :patient
  belongs_to :doctor, class_name: "User"
  belongs_to :appointment, optional: true

  validates :name, presence: true
  validates :dosage, presence: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true
  validates :route,  inclusion: { in: ROUTES },   allow_nil: true

  validate :patient_in_clinic
  validate :doctor_in_clinic

  before_validation :default_status

  scope :active, -> { where(status: "active") }
  scope :recent, -> { order(created_at: :desc) }

  def display_name
    name_ar.presence || name
  end

  private

  def default_status
    self.status ||= "active"
  end

  def patient_in_clinic
    return if patient.nil? || clinic.nil?
    errors.add(:patient, "not in this clinic") if patient.clinic_id != clinic_id
  end

  def doctor_in_clinic
    return if doctor.nil? || clinic.nil?
    errors.add(:doctor, "not in this clinic") unless doctor.member_of?(clinic)
  end
end
RUBY

cat > app/models/payment.rb <<'RUBY'
class Payment < ApplicationRecord
  STATUSES   = %w[pending paid failed refunded cancelled].freeze
  CURRENCIES = %w[SYP USD].freeze
  METHODS    = %w[cash card transfer insurance stripe].freeze

  belongs_to :clinic
  belongs_to :user
  belongs_to :patient,     optional: true
  belongs_to :appointment, optional: true

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status,   inclusion: { in: STATUSES },   allow_nil: true
  validates :currency, inclusion: { in: CURRENCIES }, allow_nil: true
  validates :method,   inclusion: { in: METHODS },    allow_nil: true

  before_validation :default_currency
  before_validation :mark_paid_at

  scope :recent,  -> { order(created_at: :desc) }
  scope :paid,    -> { where(status: "paid") }
  scope :pending, -> { where(status: "pending") }

  def display_amount
    "#{currency} #{'%.2f' % amount}"
  end

  private

  def default_currency
    self.currency ||= "SYP"
  end

  def mark_paid_at
    self.paid_at ||= Time.current if status == "paid" && paid_at.nil?
  end
end
RUBY

cat > app/models/transfer.rb <<'RUBY'
class Transfer < ApplicationRecord
  STATUSES = %w[pending accepted rejected completed cancelled].freeze

  belongs_to :clinic
  belongs_to :patient
  belongs_to :from_clinic, class_name: "Clinic", optional: true
  belongs_to :to_clinic,   class_name: "Clinic", optional: true

  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  validate :patient_belongs_to_source_clinic
  validate :destination_differs_from_source

  before_validation :default_status

  private

  def default_status
    self.status ||= "pending"
  end

  def patient_belongs_to_source_clinic
    return if patient.nil? || clinic.nil?
    errors.add(:patient, "not in this clinic") if patient.clinic_id != clinic_id
  end

  def destination_differs_from_source
    return if to_clinic_id.nil?
    errors.add(:to_clinic, "must differ from source clinic") if to_clinic_id == clinic_id
  end
end
RUBY

cat > app/models/notification.rb <<'RUBY'
class Notification < ApplicationRecord
  TYPES    = %w[appointment_reminder payment_due transfer_request system].freeze
  SEVERITY = %w[info success warning danger].freeze

  belongs_to :user
  belongs_to :notifiable, polymorphic: true, optional: true

  validates :title,    presence: true
  validates :severity, inclusion: { in: SEVERITY }, allow_nil: true

  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc) }

  def mark_read!
    update!(read: true, read_at: Time.current)
  end
end
RUBY

cat > app/models/chat_message.rb <<'RUBY'
class ChatMessage < ApplicationRecord
  ROLES = %w[user assistant system].freeze

  belongs_to :user

  validates :sender_role, inclusion: { in: ROLES }, allow_nil: true
  validates :content, presence: true

  scope :recent, -> { order(created_at: :asc) }
end
RUBY

cat > app/models/subscription.rb <<'RUBY'
class Subscription < ApplicationRecord
  PLANS    = %w[free basic pro enterprise].freeze
  STATUSES = %w[active trialing past_due cancelled expired].freeze

  belongs_to :clinic

  validates :plan,   inclusion: { in: PLANS },    allow_nil: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  scope :active, -> { where(status: "active").where("expires_at > ?", Time.current) }

  def active?
    status == "active" && expires_at&.future?
  end
end
RUBY

echo "==> Models rewritten."
echo ""
echo "==> Verifying (should print no errors):"
bin/rails runner 'puts "User: #{User.new.respond_to?(:member_of?)}"' 2>&1 | tail -3

echo "==> Done."
