import React, { useEffect, useRef, useState } from "react";
import { previewEmployees } from "./preview-employees.js";

const previewDate = "2026-11-19";
const pageSize = 6;
const emptyFilters = { search: "", country: "", department: "", role: "", status: "" };
const countryNames = { DE: "Germany", GB: "United Kingdom", IN: "India", JP: "Japan", US: "United States" };
const currencyDigits = { EUR: 2, GBP: 2, INR: 2, JPY: 0, USD: 2 };
const dateFormatter = new Intl.DateTimeFormat("en-GB", { dateStyle: "medium", timeZone: "UTC" });

function formatDate(date) {
  return dateFormatter.format(new Date(date + "T00:00:00Z"));
}

function formatSalary(amount, currency, signed = false) {
  const precision = currencyDigits[currency];
  const value = amount / 10 ** precision;
  return new Intl.NumberFormat(currency === "INR" ? "en-IN" : "en-US", {
    style: "currency",
    currency,
    minimumFractionDigits: Number.isInteger(value) ? 0 : precision,
    signDisplay: signed ? "exceptZero" : "auto",
  }).format(value);
}

function employmentStatus(employee) {
  if (employee.joinedOn > previewDate) return "Upcoming";
  if (employee.lastWorkingOn && employee.lastWorkingOn < previewDate) return "Former";
  return "Active";
}

function Status({ children }) {
  return <span className={"status-tag status-tag--" + children.toLowerCase()}>{children}</span>;
}

function FocusHeading({ children, ...props }) {
  const heading = useRef(null);
  useEffect(() => { heading.current.focus(); }, []);
  return <h1 {...props} ref={heading} tabIndex={-1}>{children}</h1>;
}

function distinct(values) {
  return [...new Set(values)].sort((first, second) => first.localeCompare(second));
}

function Filter({ field, label, value, options, renderValue = (option) => option, onChange }) {
  return (
    <div className="form-field">
      <label htmlFor={field}>{label}</label>
      <select id={field} value={value} onChange={(event) => onChange(field, event.target.value)}>
        <option value="">All</option>
        {options.map((option) => <option key={option} value={option}>{renderValue(option)}</option>)}
      </select>
    </div>
  );
}

function EmployeeDirectory({ employees, filters, page, onFilter, onClear, onPage, onSelect }) {
  const search = filters.search.trim().toLowerCase();
  const matching = employees.filter((employee) =>
    (!search || employee.name.toLowerCase().includes(search) || employee.number.toLowerCase().includes(search)) &&
    (!filters.country || employee.country === filters.country) &&
    (!filters.department || employee.department === filters.department) &&
    (!filters.role || employee.role === filters.role) &&
    (!filters.status || employmentStatus(employee) === filters.status)
  );
  const start = (page - 1) * pageSize;
  const visible = matching.slice(start, start + pageSize);
  const hasFilters = Object.values(filters).some(Boolean);
  const resultCount = `${matching.length} ${matching.length === 1 ? "employee" : "employees"}`;

  return (
    <>
      <div className="workspace-heading">
        <FocusHeading>Employees</FocusHeading>
        <p>Find an employee and open their salary history.</p>
      </div>
      <section className="workspace-card" aria-label="Employee directory">
        <div className="directory-filters">
          <div className="form-field directory-search">
            <label htmlFor="employee-search">Search employees</label>
            <input id="employee-search" type="search" placeholder="Name or employee number"
              value={filters.search} onChange={(event) => onFilter("search", event.target.value)} />
          </div>
          <Filter field="country" label="Country" value={filters.country}
            options={distinct(employees.map(({ country }) => country))}
            renderValue={(country) => countryNames[country]} onChange={onFilter} />
          <Filter field="department" label="Department" value={filters.department}
            options={distinct(employees.map(({ department }) => department))} onChange={onFilter} />
          <Filter field="role" label="Job role" value={filters.role}
            options={distinct(employees.map(({ role }) => role))} onChange={onFilter} />
          <Filter field="status" label="Status" value={filters.status}
            options={distinct(employees.map(employmentStatus))} onChange={onFilter} />
        </div>

        {visible.length ? (
          <div className="table-scroll">
            <table className="directory-table" aria-label="Employees">
              <thead>
                <tr><th scope="col">Employee</th><th scope="col">Department</th><th scope="col">Job role</th><th scope="col">Country</th><th scope="col">Status</th></tr>
              </thead>
              <tbody>
                {visible.map((employee) => (
                  <tr key={employee.number}>
                    <th scope="row">
                      <button className="employee-link" onClick={() => onSelect(employee.number)}>{employee.name}</button>
                      <span className="muted employee-number">{employee.number}</span>
                    </th>
                    <td>{employee.department}</td>
                    <td>{employee.role}</td>
                    <td>{countryNames[employee.country]}</td>
                    <td><Status>{employmentStatus(employee)}</Status></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="directory-empty">No employees match your search and filters.</p>
        )}

        <div className="directory-footer">
          <span className="muted" role="status">
            {matching.length > 1 ? `${start + 1}–${start + visible.length} of ${resultCount}` : resultCount}
          </span>
          <div className="button-group">
            {hasFilters && <button className="button button--secondary" onClick={onClear}>Clear filters</button>}
            <button className="button button--secondary" onClick={() => onPage(page - 1)} disabled={page === 1}>Previous</button>
            <button className="button button--secondary" onClick={() => onPage(page + 1)}
              disabled={start + pageSize >= matching.length}>Next</button>
          </div>
        </div>
      </section>
    </>
  );
}

function salaryTimeline(employee) {
  const salaries = [...employee.salaries].sort((first, second) => first.effectiveOn.localeCompare(second.effectiveOn));
  const effective = salaries.filter(({ effectiveOn }) => effectiveOn <= previewDate &&
    (!employee.lastWorkingOn || effectiveOn <= employee.lastWorkingOn)).at(-1);
  const current = employmentStatus(employee) === "Active" ? effective : null;

  const timeline = salaries.map((salary, index) => {
    const previous = salaries[index - 1];
    let status = "Historical";
    if (employee.lastWorkingOn && salary.effectiveOn > employee.lastWorkingOn) status = "Unapplied";
    else if (salary.effectiveOn > previewDate) status = "Scheduled";
    else if (salary === current) status = "Current";

    return { ...salary, previous, status };
  }).reverse();

  return { current, effective, timeline };
}

function SalaryChange({ salary }) {
  if (!salary.previous) return <span className="muted">Joining salary</span>;
  if (salary.status === "Unapplied") return <span className="muted">—</span>;
  if (salary.currency !== salary.previous.currency) return <span className="muted">Currency changed</span>;

  const difference = salary.amount - salary.previous.amount;
  const percentage = new Intl.NumberFormat("en", {
    style: "percent", maximumFractionDigits: 2, signDisplay: "exceptZero",
  }).format(difference / salary.previous.amount);
  return (
    <div className={difference > 0 ? "salary-increase" : undefined}>
      {formatSalary(difference, salary.currency, true)} <span className="muted">({percentage})</span>
    </div>
  );
}

function SalaryChangeForm({ employee, current, onSave, onCancel }) {
  const [error, setError] = useState("");
  const heading = useRef(null);
  useEffect(() => { heading.current.focus(); }, []);

  function submit(event) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    const currency = data.get("currency");
    const effectiveOn = data.get("effectiveOn");
    const text = data.get("amount").trim();
    const precision = currencyDigits[currency];
    const [whole, fraction = ""] = text.split(".");
    const amount = Number(whole + fraction.padEnd(precision, "0"));

    if (!/^\d+(\.\d+)?$/.test(text) || fraction.length > precision || !Number.isSafeInteger(amount) || amount <= 0) {
      setError(`Enter a positive annual salary with at most ${precision} decimal places for ${currency}.`);
      return;
    }

    if (employee.salaries.some((salary) => salary.effectiveOn === effectiveOn)) {
      setError("This employee already has a salary record for that effective date.");
      return;
    }

    onSave({ amount, currency, effectiveOn });
  }

  return (
    <section className="workspace-card salary-form-card" aria-labelledby="salary-form-title">
      <h2 id="salary-form-title" ref={heading} tabIndex={-1}>Record a salary change</h2>
      <p>Enter the full annual base salary and the date it takes effect.</p>
      <form onSubmit={submit} onChange={() => setError("")}>
        <div className="salary-form-fields">
          <div className="form-field">
            <label htmlFor="salary-amount">New annual base salary</label>
            <input id="salary-amount" name="amount" inputMode="decimal" required />
          </div>
          <div className="form-field">
            <label htmlFor="salary-currency">Currency</label>
            <select id="salary-currency" name="currency" defaultValue={current?.currency ?? "USD"}>
              {Object.keys(currencyDigits).map((currency) => <option key={currency}>{currency}</option>)}
            </select>
          </div>
          <div className="form-field">
            <label htmlFor="salary-effective-on">Effective date</label>
            <input id="salary-effective-on" name="effectiveOn" type="date" min={employee.joinedOn}
              max={employee.lastWorkingOn ?? "9999-12-31"} required />
          </div>
        </div>
        {error && <p className="form-error" role="alert">{error}</p>}
        <div className="button-group form-actions">
          <button className="button button--secondary" type="button" onClick={onCancel}>Cancel</button>
          <button className="button button--primary" type="submit">Save salary change</button>
        </div>
      </form>
    </section>
  );
}

function EmployeeDetail({ employee, onBack, onSave }) {
  const [showForm, setShowForm] = useState(false);
  const [notice, setNotice] = useState("");
  const recordButton = useRef(null);
  const status = employmentStatus(employee);
  const { current, effective, timeline } = salaryTimeline(employee);
  const displayedSalary = current ?? effective;

  function closeForm() {
    setShowForm(false);
    recordButton.current?.focus();
  }

  function recordSalary(salary) {
    onSave(salary);
    closeForm();
    setNotice(salary.effectiveOn > previewDate
      ? `Salary change scheduled for ${formatDate(salary.effectiveOn)}.`
      : `Salary change added for ${formatDate(salary.effectiveOn)}.`);
  }

  return (
    <>
      <button className="back-link" onClick={onBack}>← Back to employees</button>
      <div className="workspace-heading employee-heading">
        <div>
          <FocusHeading>{employee.name}</FocusHeading>
          <p>{employee.number} · {employee.role}</p>
        </div>
        {status === "Active" && (
          <button className="button button--primary" ref={recordButton} onClick={() => {
            setNotice("");
            setShowForm(true);
          }}>Record salary change</button>
        )}
      </div>

      <dl className="employee-summary">
        <div className="workspace-card">
          <dt>{current ? "Current annual base salary" : "Last annual base salary"}</dt>
          <dd>{displayedSalary ? formatSalary(displayedSalary.amount, displayedSalary.currency) : "—"}</dd>
          {displayedSalary && <dd className="muted summary-note">{displayedSalary.currency} · Effective {formatDate(displayedSalary.effectiveOn)}</dd>}
        </div>
        <div className="workspace-card">
          <dt>Employment</dt>
          <dd><Status>{status}</Status></dd>
          <dd className="muted summary-note">Joined {formatDate(employee.joinedOn)}</dd>
          {employee.lastWorkingOn && <dd className="muted summary-note">Last working day {formatDate(employee.lastWorkingOn)}</dd>}
        </div>
        <div className="workspace-card">
          <dt>Work location</dt>
          <dd>{countryNames[employee.country]}</dd>
          <dd className="muted summary-note">{employee.department}</dd>
        </div>
      </dl>

      {showForm && <SalaryChangeForm employee={employee} current={current} onSave={recordSalary} onCancel={closeForm} />}
      {notice && <p className="workspace-notice" role="status">{notice}</p>}
      <section className="workspace-card" aria-labelledby="salary-history-heading">
        <div className="section-heading">
          <h2 id="salary-history-heading">Salary history</h2>
          <p>Annual base salary by effective date.</p>
        </div>
        <div className="table-scroll">
          <table aria-label="Salary history">
            <thead><tr><th scope="col">Effective date</th><th scope="col">Annual base salary</th><th scope="col">Change</th><th scope="col">Status</th></tr></thead>
            <tbody>
              {timeline.map((salary) => (
                <tr key={salary.effectiveOn}>
                  <th scope="row">{formatDate(salary.effectiveOn)}</th>
                  <td>
                    {formatSalary(salary.amount, salary.currency)} <span className="muted">{salary.currency}</span>
                    {salary.previous && <span className="muted salary-previous">
                      From {formatSalary(salary.previous.amount, salary.previous.currency)} {salary.previous.currency}
                    </span>}
                  </td>
                  <td><SalaryChange salary={salary} /></td>
                  <td><Status>{salary.status}</Status></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}

export function EmployeePreview({ onSignOut }) {
  const [employees, setEmployees] = useState(previewEmployees);
  const [selected, setSelected] = useState(null);
  const [filters, setFilters] = useState(emptyFilters);
  const [page, setPage] = useState(1);
  const employee = employees.find(({ number }) => number === selected);

  function changeFilter(field, value) {
    setFilters((previous) => ({ ...previous, [field]: value }));
    setPage(1);
  }

  function clearFilters() {
    setFilters(emptyFilters);
    setPage(1);
  }

  function saveSalary(salary) {
    setEmployees((previous) => previous.map((record) => record.number === selected
      ? { ...record, salaries: [...record.salaries, salary] }
      : record));
  }

  return (
    <div className="workspace">
      <header className="workspace-header">
        <div className="workspace-header__inner">
          <div className="workspace-brand"><strong>ACME</strong><span>Salary Management</span></div>
          <button className="button button--secondary" onClick={onSignOut}>Sign out</button>
        </div>
      </header>
      <main className="workspace-main">
        <p className="preview-banner">Design preview · Sample data as of {formatDate(previewDate)} · Changes reset on refresh or sign-out</p>
        {employee ? (
          <EmployeeDetail key={employee.number} employee={employee} onBack={() => setSelected(null)} onSave={saveSalary} />
        ) : (
          <EmployeeDirectory employees={employees} filters={filters} page={page}
            onFilter={changeFilter} onClear={clearFilters} onPage={setPage} onSelect={setSelected} />
        )}
      </main>
    </div>
  );
}
