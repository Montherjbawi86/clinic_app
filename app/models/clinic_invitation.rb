class ClinicInvitation < ApplicationRecord
  ROLES = %w[owner doctor nurse receptionist accountant].freeze

  belongs_to :clinic
  belongs_to :invited_by, class_name: "User", optional: true

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role,  inclusion: { in: ROLES }
  validates :email, uniqueness: { scope: :clinic_id, message: "already invited" }

  before_validation :normalize_email
  before_validation :generate_token, on: :create
  before_validation :set_expiry,     on: :create

  scope :pending,  -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }
  scope :accepted, -> { where.not(accepted_at: nil) }
  scope :expired,  -> { where(accepted_at: nil).where("expires_at <= ?", Time.current) }

  def pending?;  accepted_at.nil? && expires_at&.future?; end
  def expired?;  accepted_at.nil? && expires_at&.past?;   end
  def accepted?; accepted_at.present?;                     end

  def accept!(user)
    transaction do
      clinic.clinic_members.find_or_create_by!(user: user) do |m|
        m.role = role
      end
      update!(accepted_at: Time.current)
    end
  end

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(24)
  end

  def set_expiry
    self.expires_at ||= 7.days.from_now
  end
end
