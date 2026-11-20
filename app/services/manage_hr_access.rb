class ManageHrAccess
  class InvalidOperation < StandardError; end

  def initialize(actor:, date:)
    @actor = actor
    @date = date
  end

  def call(target_id:, action:, input: {})
    HrAccount.transaction do
      @actor.reload
      unless @actor.role_access_admin? && @actor.sign_in_allowed_on?(@date)
        raise InvalidOperation, "Active Access Admin permissions are required."
      end

      target = HrAccount.where(role: %i[employee hr_manager]).find(target_id)

      next transfer(target, input) if action == "transfer"

      event_date = case action
      when "grant"
        grant(target)
        nil
      when "revoke"
        revoke(target)
        nil
      when "record_departure"
        date = parse_date(input[:last_working_on])
        if target.employee.last_working_on != date
          record_departure(target, date)
          date
        end
      else
        raise InvalidOperation, "Choose a valid access action."
      end

      if action != "record_departure" || event_date
        AccountAccessEvent.create!(actor: @actor, target: target, action: action, last_working_on: event_date)
      end
      target
    end
  end

  def transfer_candidate(target_id:, employee_number:)
    outgoing = HrAccount.where(role: :hr_manager).where.not(email: nil).find(target_id)
    find_replacement(outgoing, employee_number)
  end

  private

  def grant(target)
    raise InvalidOperation, "This account no longer has a login email." if target.email.blank?
    unless target.active_on?(@date)
      raise InvalidOperation, "HR access can only be granted to an active employee."
    end
    raise InvalidOperation, "This account already has HR access." if target.access_enabled?

    target.update!(role: :hr_manager, access_enabled: true, access_version: target.access_version + 1)
  end

  def transfer(outgoing, input)
    unless outgoing.role_hr_manager? && outgoing.email.present?
      raise InvalidOperation, "Choose an HR account with a login email to transfer."
    end

    replacement = find_replacement(outgoing, input[:employee_number])
    incoming = replacement.hr_account || replacement.build_hr_account
    password, confirmation = input.values_at(:password, :password_confirmation)
    unless password.is_a?(String) && password.length >= 12 && password.bytesize <= 72 && password == confirmation
      raise InvalidOperation, "Enter matching temporary passwords with at least 12 characters and at most 72 bytes."
    end
    if outgoing.valid_password?(password) || (incoming.persisted? && incoming.valid_password?(password))
      raise InvalidOperation, "Choose a temporary password different from both accounts' existing passwords."
    end

    email = outgoing.email
    outgoing.update!(email: nil, access_enabled: false, password_change_required: false,
      access_version: outgoing.access_version + 1)
    incoming.update!(email: email, role: :hr_manager, access_enabled: true, password: password,
      password_confirmation: confirmation, password_change_required: true, access_version: incoming.access_version + 1)
    AccountAccessEvent.create!(actor: @actor, target: incoming, outgoing_account: outgoing, action: "transfer")
    incoming
  end

  def find_replacement(outgoing, number)
    unless number.is_a?(String) && number.present? && number.bytesize <= 200
      raise InvalidOperation, "Enter the replacement's employee number."
    end

    replacement = Employee.find_by(employee_number: number)
    unless replacement&.employed_on?(@date) && replacement.id != outgoing.employee_id
      raise InvalidOperation, "Choose a different employee who is active today."
    end
    incoming = replacement.hr_account
    if incoming && (incoming.role_access_admin? || incoming.access_enabled?)
      raise InvalidOperation, "The replacement already has an enabled account or is an Access Admin."
    end
    replacement
  end

  def revoke(target)
    unless target.role_hr_manager? && target.access_enabled?
      raise InvalidOperation, "This account does not have HR access to revoke."
    end

    target.update!(access_enabled: false, access_version: target.access_version + 1)
  end

  def record_departure(target, date)
    raise InvalidOperation, "Only an HR manager’s departure can be recorded here." unless target.role_hr_manager?

    target.employee.record_departure!(date, as_of: @date)
  end

  def parse_date(value)
    return Date.iso8601(value) if value.is_a?(String) && /\A\d{4}-\d{2}-\d{2}\z/.match?(value)

    raise InvalidOperation, "Enter a valid last working day."
  rescue Date::Error
    raise InvalidOperation, "Enter a valid last working day."
  end
end
