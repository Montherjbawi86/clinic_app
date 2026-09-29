class Patient < ApplicationRecord
  belongs_to :clinic
  has_many :appointments, dependent: :destroy
  has_many :medical_reports, dependent: :destroy
  has_many :medications, dependent: :destroy
  has_many :transfers, dependent: :destroy

  validates :name, presence: true
end
