class AccountAccessEvent < ApplicationRecord
  belongs_to :actor, class_name: "HrAccount"
  belongs_to :target, class_name: "HrAccount"
  belongs_to :outgoing_account, class_name: "HrAccount", optional: true

  validates :action, inclusion: { in: %w[grant revoke record_departure transfer] }
  validates :outgoing_account, presence: true, if: -> { action == "transfer" }
end
