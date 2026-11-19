class JobRole < ApplicationRecord
  has_many :employees

  normalizes :name, with: ->(name) { name.strip }
  validates :name, presence: true, length: { maximum: 120 }, uniqueness: { case_sensitive: false }
end
