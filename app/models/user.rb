class User < ApplicationRecord
  include Discard::Model

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
  has_many :sent_invitations, class_name: "ClinicInvitation", foreign_key: "invited_by_id", dependent: :nullify

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role,   inclusion: { in: ROLES },   allow_nil: true
  validates :locale, inclusion: { in: LOCALES }, allow_nil: true

  before_validation { self.email = email.to_s.downcase.strip }


  def self.search(q)
    return all if q.blank?
    where("name ILIKE :q OR email ILIKE :q", q: "%#{q}%")
  end

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

  def deactivate!
    update!(discarded_at: Time.current)
  end

  def activate!
    update!(discarded_at: nil)
  end

  def active?
    discarded_at.nil?
  end

  def suspended?
    discarded_at.present?
  end
end
