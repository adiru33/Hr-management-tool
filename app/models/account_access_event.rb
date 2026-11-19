class AccountAccessEvent < ApplicationRecord
  belongs_to :actor, class_name: "HrAccount"
  belongs_to :target, class_name: "HrAccount"

  validates :action, inclusion: { in: %w[grant revoke record_departure] }
end
