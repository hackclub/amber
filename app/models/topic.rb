class Topic < ApplicationRecord
  belongs_to :service
  has_many :tickets, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :service_id }

  scope :active, -> { where(active: true) }
end
