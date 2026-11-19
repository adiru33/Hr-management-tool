class ManageHrAccess
  class InvalidOperation < StandardError; end

  def initialize(actor:, date:)
    @actor = actor
    @date = date
  end

  def call(target_id:, action:, last_working_on: nil)
    HrAccount.transaction do
      @actor.reload
      unless @actor.role_access_admin? && @actor.sign_in_allowed_on?(@date)
        raise InvalidOperation, "Active Access Admin permissions are required."
      end

      target = HrAccount.where(role: %i[employee hr_manager]).find(target_id)

      event_date = case action
      when "grant"
        grant(target)
        nil
      when "revoke"
        revoke(target)
        nil
      when "record_departure"
        date = parse_date(last_working_on)
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

  private

  def grant(target)
    unless target.active_on?(@date)
      raise InvalidOperation, "HR access can only be granted to an active employee."
    end
    raise InvalidOperation, "This account already has HR access." if target.access_enabled?

    target.update!(role: :hr_manager, access_enabled: true, access_version: target.access_version + 1)
  end

  def revoke(target)
    unless target.role_hr_manager? && target.access_enabled?
      raise InvalidOperation, "This account does not have HR access to revoke."
    end

    target.update!(access_enabled: false, access_version: target.access_version + 1)
  end

  def record_departure(target, date)
    raise InvalidOperation, "Only an HR manager’s departure can be recorded here." unless target.role_hr_manager?

    was_active = target.active_on?(@date)
    target.employee.update!(last_working_on: date)
    if was_active != target.active_on?(@date)
      target.update!(access_version: target.access_version + 1)
    end
  end

  def parse_date(value)
    return Date.iso8601(value) if value.is_a?(String) && /\A\d{4}-\d{2}-\d{2}\z/.match?(value)

    raise InvalidOperation, "Enter a valid last working day."
  rescue Date::Error
    raise InvalidOperation, "Enter a valid last working day."
  end
end
