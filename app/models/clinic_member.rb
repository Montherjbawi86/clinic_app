class ClinicMember < ApplicationRecord
  ROLES = %w[owner doctor nurse receptionist accountant].freeze

  belongs_to :clinic
  belongs_to :user

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :clinic_id, message: "already a member of this clinic" }
end
