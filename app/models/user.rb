class User < ApplicationRecord
  has_secure_password
  has_many :clinics, foreign_key: "user_id", dependent: :destroy
  has_many :appointments, foreign_key: "doctor_id", dependent: :nullify
  has_many :payments, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :chat_messages, dependent: :destroy
end
