import React, { useEffect, useRef, useState } from "react";

function FormInput({ name, label, ...props }) {
  const id = `employee-${name}`;
  return <div className="form-field">
    <label htmlFor={id}>{label}</label>
    <input id={id} name={name} required {...props} />
  </div>;
}

function FormSelect({ name, label, options, defaultValue, renderOption = (option) => option }) {
  const id = `employee-${name}`;
  return <div className="form-field">
    <label htmlFor={id}>{label}</label>
    <select id={id} name={name} defaultValue={defaultValue ?? ""} required>
      <option value="" disabled>Choose {label.toLowerCase()}</option>
      {options.map((option) => <option key={option} value={option}>{renderOption(option)}</option>)}
    </select>
  </div>;
}

function errorMessage(failure) {
  return failure.status ? failure.message : "Unable to reach the server. Please try again.";
}

export function EmployeeForm({ employee, options, countries, onSave, onCancel }) {
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const heading = useRef(null);
  useEffect(() => { heading.current.focus(); }, []);

  async function submit(event) {
    event.preventDefault();
    const data = Object.fromEntries(new FormData(event.currentTarget));
    setSaving(true);
    setError("");
    try {
      await onSave(data);
    } catch (failure) {
      setError(errorMessage(failure));
    } finally {
      setSaving(false);
    }
  }

  return <>
    <div className="workspace-heading">
      <h1 ref={heading} tabIndex={-1}>{employee ? "Edit employee" : "Add employee"}</h1>
      <p>{employee ? `${employee.name} · ${employee.number}` : "Create a profile and its starting annual salary together."}</p>
    </div>
    <form className="workspace-card salary-form-card profile-form" onSubmit={submit} onChange={() => setError("")}>
      <fieldset disabled={saving}>
        <legend>Employee details</legend>
        <div className="profile-fields">
          {!employee && <FormInput name="employee_number" label="Employee number" maxLength={50} />}
          <FormInput name="full_name" label="Full name" maxLength={120} defaultValue={employee?.name} />
          <FormSelect name="country_code" label="Work country" options={options.countries}
            defaultValue={employee?.country} renderOption={(code) => countries[code] ?? code} />
          <FormSelect name="department" label="Department" options={options.departments} defaultValue={employee?.department} />
          <FormSelect name="job_role" label="Job role" options={options.roles} defaultValue={employee?.role} />
          {!employee && <FormInput name="joined_on" label="Joining date" type="date" max="9999-12-31" />}
        </div>
      </fieldset>
      {!employee && <fieldset disabled={saving}>
        <legend>Starting compensation</legend>
        <div className="profile-fields">
          <FormInput name="annual_salary" label="Starting annual base salary" inputMode="decimal" maxLength={32} />
          <FormSelect name="currency" label="Currency" options={options.currencies} />
        </div>
      </fieldset>}
      {error && <p className="form-error" role="alert">{error}</p>}
      <div className="button-group form-actions">
        <button className="button button--secondary" type="button" disabled={saving} onClick={onCancel}>Cancel</button>
        <button className="button button--primary" type="submit" disabled={saving}>
          {saving ? "Saving…" : employee ? "Save profile" : "Create employee"}
        </button>
      </div>
    </form>
  </>;
}

export function DepartureForm({ employee, onSave, onCancel }) {
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);
  const heading = useRef(null);
  useEffect(() => { heading.current.focus(); }, []);

  async function submit(event) {
    event.preventDefault();
    const data = Object.fromEntries(new FormData(event.currentTarget));
    setError("");
    setSaving(true);
    try {
      await onSave(data);
    } catch (failure) {
      setError(errorMessage(failure));
    } finally {
      setSaving(false);
    }
  }

  return <section className="workspace-card salary-form-card" aria-labelledby="departure-heading">
    <h2 id="departure-heading" ref={heading} tabIndex={-1}>Record departure</h2>
    <p>The employee remains active through their last working day. Their salary history stays available afterward.</p>
    <form onSubmit={submit} onChange={() => setError("")}>
      <div className="salary-form-fields">
        <FormInput name="last_working_on" label="Last working day" type="date"
          min={employee.joinedOn} max="9999-12-31" defaultValue={employee.lastWorkingOn} disabled={saving} />
      </div>
      {error && <p className="form-error" role="alert">{error}</p>}
      <div className="button-group form-actions">
        <button className="button button--secondary" type="button" disabled={saving} onClick={onCancel}>Cancel</button>
        <button className="button button--primary" type="submit" disabled={saving}>
          {saving ? "Saving…" : "Save last working day"}
        </button>
      </div>
    </form>
  </section>;
}
