class Department < ApplicationRecord
  has_many :employees

  normalizes :name, with: ->(name) { name.strip }
  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
