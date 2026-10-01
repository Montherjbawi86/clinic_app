class ChatMessage < ApplicationRecord
  ROLES = %w[user assistant system].freeze

  belongs_to :user

  validates :sender_role, inclusion: { in: ROLES }, allow_nil: true
  validates :content, presence: true

  scope :recent, -> { order(created_at: :asc) }
end
