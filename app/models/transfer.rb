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
