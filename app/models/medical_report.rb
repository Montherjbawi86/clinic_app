class MedicalReport < ApplicationRecord
  belongs_to :clinic
  belongs_to :patient
  belongs_to :doctor, class_name: "User"
end
