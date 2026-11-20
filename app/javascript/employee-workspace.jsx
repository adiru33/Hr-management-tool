import React, { useEffect, useRef, useState } from "react";
import { api } from "./api.js";
import { Filter, FocusHeading, Workspace } from "./workspace.jsx";
import { countryNames, formatDate, formatSalary } from "./formatting.js";
import { DepartureForm, EmployeeForm } from "./employee-form.jsx";
import { EmployeeImportForm } from "./employee-import-form.jsx";

const emptyFilters = { search: "", country: "", department: "", role: "", status: "" };

function Status({ children }) {
  return <span className={"status-tag status-tag--" + children.toLowerCase()}>{children}</span>;
}

function EmployeeDirectory({ data, busy, error, filters, onFilter, onClear, onPage, onSelect, onRetry, onAdd, onImport }) {
  const { employees: visible = [], page = 1, pageSize = 25, total = 0, filters: options } = data ?? {};
  const start = (page - 1) * pageSize;
  const hasFilters = Object.values(filters).some(Boolean);
  const resultCount = `${total.toLocaleString()} ${total === 1 ? "employee" : "employees"}`;

  return (
    <>
      <div className="workspace-heading employee-heading">
        <div>
          <FocusHeading>Employees</FocusHeading>
          <p>Find an employee and open their salary history.</p>
        </div>
        <div className="button-group">
          <button className="button button--secondary" onClick={onImport}>Import CSV</button>
          <button className="button button--primary" onClick={onAdd} disabled={!options}>Add employee</button>
        </div>
      </div>
      <section className="workspace-card" aria-label="Employee directory">
        <div className="directory-filters">
          <div className="form-field directory-search">
            <label htmlFor="employee-search">Search employees</label>
            <input id="employee-search" type="search" placeholder="Name or employee number"
              value={filters.search} onChange={(event) => onFilter("search", event.target.value)} />
          </div>
          <Filter field="country" label="Country" value={filters.country}
            options={options?.countries ?? []}
            renderValue={(country) => countryNames[country]} onChange={onFilter} />
          <Filter field="department" label="Department" value={filters.department}
            options={options?.departments ?? []} onChange={onFilter} />
          <Filter field="role" label="Job role" value={filters.role}
            options={options?.roles ?? []} onChange={onFilter} />
          <Filter field="status" label="Status" value={filters.status}
            options={options?.statuses ?? []} onChange={onFilter} />
        </div>

        {error ? (
          <div className="directory-empty">
            <p role="alert">{error}</p>
            <button className="button button--secondary" onClick={onRetry}>Try again</button>
          </div>
        ) : busy ? (
          <p className="directory-empty" role="status">Loading employees…</p>
        ) : visible.length ? (
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
                    <td><Status>{employee.status}</Status></td>
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
            {!busy && !error && (total > 1
              ? `${(start + 1).toLocaleString()}–${(start + visible.length).toLocaleString()} of ${resultCount}`
              : resultCount)}
          </span>
          <div className="button-group">
            {hasFilters && <button className="button button--secondary" onClick={onClear}>Clear filters</button>}
            <button className="button button--secondary" onClick={() => onPage(page - 1)} disabled={busy || Boolean(error) || page === 1}>Previous</button>
            <button className="button button--secondary" onClick={() => onPage(page + 1)}
              disabled={busy || Boolean(error) || start + pageSize >= total}>Next</button>
          </div>
        </div>
      </section>
    </>
  );
}

function SalaryChange({ salary }) {
  if (!salary.previous) return <span className="muted">Joining salary</span>;
  if (salary.status === "Unapplied") return <span className="muted">—</span>;
  if (salary.currency !== salary.previous.currency) return <span className="muted">Currency changed</span>;

  if (!salary.change) return <span className="muted">—</span>;

  const difference = BigInt(salary.change.amount);
  const percentage = new Intl.NumberFormat("en", {
    style: "percent", maximumFractionDigits: 2, signDisplay: "exceptZero",
  }).format(salary.change.percentage / 100);
  return (
    <div className={difference > 0 ? "salary-increase" : undefined}>
      {formatSalary(difference, salary.currency, true)} <span className="muted">({percentage})</span>
    </div>
  );
}

function SalaryChangeForm({ employee, current, onSave, onCancel }) {
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);
  const heading = useRef(null);
  useEffect(() => { heading.current.focus(); }, []);

  async function submit(event) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    setError("");
    setSaving(true);
    try {
      await onSave({
        amount: data.get("amount"),
        currency: data.get("currency"),
        effective_on: data.get("effectiveOn"),
      });
    } catch (failure) {
      setError(failure.status ? failure.message : "Unable to reach the server. Please try again.");
    } finally {
      setSaving(false);
    }
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
              {Object.keys(employee.currencies).map((currency) => <option key={currency}>{currency}</option>)}
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
          <button className="button button--secondary" type="button" onClick={onCancel} disabled={saving}>Cancel</button>
          <button className="button button--primary" type="submit" disabled={saving}>
            {saving ? "Saving…" : "Save salary change"}
          </button>
        </div>
      </form>
    </section>
  );
}

function EmployeeDetail({ employee, onBack, onSave, onEdit, onDeparture, onExport, profileNotice }) {
  const [form, setForm] = useState(null);
  const [notice, setNotice] = useState(profileNotice);
  const [exporting, setExporting] = useState(false);
  const [exportError, setExportError] = useState("");
  const recordButton = useRef(null);
  const departureButton = useRef(null);
  const { status, current, lastEffective, timeline } = employee;
  const displayedSalary = current ?? lastEffective;

  function closeForm() {
    setForm(null);
    (form === "departure" ? departureButton : recordButton).current?.focus();
  }

  async function recordSalary(input) {
    const updated = await onSave(employee.number, input);
    const salary = updated.timeline.find(({ effectiveOn }) => effectiveOn === input.effective_on);
    closeForm();
    setNotice(salary.status === "Scheduled"
      ? `Salary change scheduled for ${formatDate(salary.effectiveOn)}.`
      : `Salary change added for ${formatDate(salary.effectiveOn)}.`);
  }

  async function recordDeparture(input) {
    await onDeparture(employee.number, input);
    closeForm();
    setNotice(`Last working day recorded as ${formatDate(input.last_working_on)}.`);
  }

  async function downloadSalaryHistory() {
    setExporting(true);
    setExportError("");
    try {
      const csv = await onExport(employee.number);
      const url = URL.createObjectURL(csv);
      const link = document.createElement("a");
      link.href = url;
      link.download = `employee-${employee.number}-salary-history.csv`;
      document.body.append(link);
      link.click();
      link.remove();
      window.setTimeout(() => URL.revokeObjectURL(url), 1000);
    } catch (failure) {
      setExportError(failure.status ? failure.message : "Unable to download the salary history. Please try again.");
    } finally {
      setExporting(false);
    }
  }

  return (
    <>
      <button className="back-link" onClick={onBack}>← Back to employees</button>
      <div className="workspace-heading employee-heading">
        <div>
          <FocusHeading>{employee.name}</FocusHeading>
          <p>{employee.number} · {employee.role}</p>
        </div>
        <div className="button-group">
          <button className="button button--secondary" onClick={onEdit}>Edit employee</button>
          {employee.canRecordDeparture && (
            <button className="button button--secondary" ref={departureButton} onClick={() => {
              setNotice("");
              setForm("departure");
            }}>{employee.lastWorkingOn ? "Update last working day" : "Record departure"}</button>
          )}
          {employee.canRecordSalary && (
            <button className="button button--primary" ref={recordButton} onClick={() => {
              setNotice("");
              setForm("salary");
            }}>Record salary change</button>
          )}
        </div>
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

      {form === "salary" && <SalaryChangeForm employee={employee} current={current} onSave={recordSalary} onCancel={closeForm} />}
      {form === "departure" && <DepartureForm employee={employee} onSave={recordDeparture} onCancel={closeForm} />}
      {notice && <p className="workspace-notice" role="status">{notice}</p>}
      <section className="workspace-card" aria-labelledby="salary-history-heading">
        <div className="section-heading salary-history-heading">
          <div>
            <h2 id="salary-history-heading">Salary history</h2>
            <p>Annual base salary by effective date.</p>
          </div>
          <button className="button button--secondary" type="button" disabled={exporting}
            onClick={downloadSalaryHistory}>{exporting ? "Preparing CSV…" : "Download CSV"}</button>
        </div>
        {exportError && <p className="form-error section-heading" role="alert">{exportError}</p>}
        <div className="table-scroll">
          <table aria-label="Salary history">
            <thead><tr><th scope="col">Effective date</th><th scope="col">Annual base salary</th><th scope="col">Change</th><th scope="col">Status</th><th scope="col">Recorded by</th></tr></thead>
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
                  <td>{salary.recordedBy}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}

export function EmployeeWorkspace({ account, onSignOut, onSessionError, navigation }) {
  const [filters, setFilters] = useState(emptyFilters);
  const [page, setPage] = useState(1);
  const [selected, setSelected] = useState(null);
  const [directory, setDirectory] = useState(null);
  const [employee, setEmployee] = useState(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(true);
  const [attempt, setAttempt] = useState(0);
  const [profileMode, setProfileMode] = useState(null);
  const [profileNotice, setProfileNotice] = useState("");

  useEffect(() => {
    if (profileMode) return;
    const controller = new AbortController();
    const query = new URLSearchParams({ ...filters, page });
    const path = selected ? `/api/employees/${encodeURIComponent(selected)}` : `/api/employees?${query}`;

    const timer = setTimeout(async () => {
      try {
        const data = await api(path, { signal: controller.signal });
        if (!controller.signal.aborted) {
          if (selected) setEmployee(data);
          else setDirectory(data);
        }
      } catch (failure) {
        if (!controller.signal.aborted) {
          if (!onSessionError(failure)) setError(failure.status ? failure.message : "Unable to reach the server.");
        }
      } finally {
        if (!controller.signal.aborted) setBusy(false);
      }
    }, selected ? 0 : 150);

    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [filters, page, selected, attempt, profileMode, onSessionError]);

  function startLoading() {
    setError("");
    setBusy(true);
  }

  function changeFilter(field, value) {
    if (filters[field] === value) return;
    startLoading();
    setFilters((previous) => ({ ...previous, [field]: value }));
    setPage(1);
  }

  function clearFilters() {
    startLoading();
    setFilters(emptyFilters);
    setPage(1);
  }

  function changePage(nextPage) {
    startLoading();
    setPage(nextPage);
  }

  function selectEmployee(number) {
    startLoading();
    setEmployee(null);
    setProfileNotice("");
    setSelected(number);
  }

  function retry() {
    startLoading();
    setAttempt((previous) => previous + 1);
  }

  async function write(path, method, body) {
    try {
      return await api(path, { method, body });
    } catch (failure) {
      onSessionError(failure);
      throw failure;
    }
  }

  async function updateEmployee(number, path, method, input) {
    const updated = await write(`/api/employees/${encodeURIComponent(number)}${path}`, method, input);
    setEmployee((current) => current?.number === number ? updated : current);
    return updated;
  }

  async function saveProfile(input) {
    const editing = profileMode === "edit";
    const path = editing ? `/api/employees/${encodeURIComponent(selected)}` : "/api/employees";
    const updated = await write(path, editing ? "PATCH" : "POST", input);
    setEmployee(updated);
    setSelected(updated.number);
    setProfileNotice(editing ? "Employee profile updated." : "Employee and starting salary created.");
    setProfileMode(null);
  }

  async function exportEmployee(number) {
    try {
      return await api(`/api/employees/${encodeURIComponent(number)}/salary_history`, { responseType: "csv" });
    } catch (failure) {
      onSessionError(failure);
      throw failure;
    }
  }

  const asOf = employee?.asOf ?? directory?.asOf;

  return (
    <Workspace account={account} onSignOut={onSignOut} navigation={navigation}>
        {asOf && <p className="workspace-date">Compensation as of {formatDate(asOf)}</p>}
        {profileMode === "import" ? (
          <EmployeeImportForm onUpload={(file) => write("/api/employees/import", "POST", file)}
            onBack={() => { startLoading(); setProfileMode(null); }} />
        ) : profileMode ? (
          <EmployeeForm employee={profileMode === "edit" ? employee : null} options={directory.filters}
            countries={countryNames} onSave={saveProfile} onCancel={() => setProfileMode(null)} />
        ) : selected ? (
          employee ? (
            <EmployeeDetail key={employee.number} employee={employee}
              profileNotice={profileNotice} onBack={() => selectEmployee(null)} onEdit={() => setProfileMode("edit")}
              onSave={(number, input) => updateEmployee(number, "/salary_records", "POST", input)}
              onDeparture={(number, input) => updateEmployee(number, "/departure", "PATCH", input)}
              onExport={exportEmployee} />
          ) : (
            <>
              <button className="back-link" onClick={() => selectEmployee(null)}>← Back to employees</button>
              {error ? <>
                <p role="alert">{error}</p>
                <button className="button button--secondary" onClick={retry}>Try again</button>
              </> : <p role="status">Loading salary history…</p>}
            </>
          )
        ) : (
          <EmployeeDirectory data={directory} busy={busy} error={error} filters={filters} onFilter={changeFilter}
            onClear={clearFilters} onPage={changePage} onSelect={selectEmployee} onRetry={retry}
            onAdd={() => setProfileMode("add")} onImport={() => setProfileMode("import")} />
        )}
    </Workspace>
  );
}
