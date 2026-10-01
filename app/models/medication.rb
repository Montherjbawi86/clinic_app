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
  before_validation :generate_public_token, on: :create

  scope :active, -> { where(status: "active") }
  scope :recent, -> { order(created_at: :desc) }

  def display_name
    name_ar.presence || name
  end

  private

  def default_status
    self.status ||= "active"
  end

  def generate_public_token
    self.public_token ||= SecureRandom.urlsafe_base64(16)
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
