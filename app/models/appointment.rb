class Appointment < ApplicationRecord
  belongs_to :clinic
  belongs_to :patient
  belongs_to :doctor, class_name: "User", optional: true

  validates :appointment_date, presence: true
  validates :patient_id, presence: true
end
