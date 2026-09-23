class Service < ApplicationRecord
  has_many :topics, dependent: :restrict_with_error
  has_many :tickets, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }
end
