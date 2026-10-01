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
