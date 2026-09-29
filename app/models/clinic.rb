class Clinic < ApplicationRecord
  belongs_to :owner, class_name: "User", foreign_key: "user_id"
  has_many :clinic_members, dependent: :destroy
  has_many :patients, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :medical_reports, dependent: :destroy
  has_many :medications, dependent: :destroy
  has_many :transfers, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
end
