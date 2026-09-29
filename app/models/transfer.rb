class Transfer < ApplicationRecord
  belongs_to :clinic
  belongs_to :patient
end
