import React, { useEffect, useState } from "react";
import { api } from "./api.js";
import { countryNames, formatDate, formatSalary } from "./formatting.js";
import { Filter, FocusHeading, Workspace } from "./workspace.jsx";

const emptyFilters = { country: "", department: "", role: "" };

function CompensationTable({ report }) {
  if (!report.total) {
    return <p className="directory-empty">No active employees with a current salary match these filters.</p>;
  }

  return <>
    <div className="table-scroll">
      <table aria-label="Current compensation by currency">
        <thead>
          <tr>
            <th scope="col">Currency</th>
            <th scope="col">Headcount</th>
            <th scope="col">Mean annual salary</th>
            <th scope="col">Median annual salary</th>
          </tr>
        </thead>
        <tbody>
          {report.groups.map((group) => (
            <tr key={group.currency}>
              <th scope="row">{group.currency}</th>
              <td>{group.headcount.toLocaleString()}</td>
              <td>{formatSalary(group.meanMinor, group.currency)}</td>
              <td>{formatSalary(group.medianMinor, group.currency)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
    <div className="directory-footer" role="status">
      {report.total.toLocaleString()} {report.total === 1 ? "employee" : "employees"} with a current salary
    </div>
  </>;
}

export function CompensationWorkspace({ account, navigation, onSignOut, onSessionError }) {
  const [filters, setFilters] = useState(emptyFilters);
  const [report, setReport] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const request = new AbortController();
    const query = new URLSearchParams(filters);
    api(`/api/compensation?${query}`, { signal: request.signal })
      .then((data) => { if (!request.signal.aborted) setReport(data); })
      .catch((failure) => {
        if (!request.signal.aborted && !onSessionError(failure)) {
          setError(failure.status ? failure.message : "Unable to reach the server. Please try again.");
        }
      })
      .finally(() => { if (!request.signal.aborted) setLoading(false); });
    return () => request.abort();
  }, [filters, attempt, onSessionError]);

  function fetchWith(nextFilters) {
    setLoading(true);
    setError("");
    setFilters(nextFilters);
  }

  function changeFilter(field, value) {
    fetchWith({ ...filters, [field]: value });
  }

  function retry() {
    setLoading(true);
    setError("");
    setAttempt((previous) => previous + 1);
  }

  const options = report?.filters;
  const hasFilters = Object.values(filters).some(Boolean);

  return (
    <Workspace account={account} onSignOut={onSignOut} navigation={navigation}>
      {report && <p className="workspace-date">Compensation as of {formatDate(report.asOf)}</p>}
      <div className="workspace-heading">
        <FocusHeading>Compensation overview</FocusHeading>
        <p>Compare current annual base salaries for active employees in each currency.</p>
      </div>
      <section className="workspace-card" aria-label="Compensation results" aria-busy={loading}>
        <div className="directory-filters compensation-filters">
          <Filter field="country" label="Country" value={filters.country} options={options?.countries ?? []}
            renderValue={(code) => countryNames[code] ?? code} onChange={changeFilter} />
          <Filter field="department" label="Department" value={filters.department}
            options={options?.departments ?? []} onChange={changeFilter} />
          <Filter field="role" label="Job role" value={filters.role} options={options?.roles ?? []} onChange={changeFilter} />
          {hasFilters && <button className="button button--secondary" onClick={() => fetchWith(emptyFilters)}>Clear filters</button>}
        </div>
        {error ? (
          <div className="directory-empty">
            <p role="alert">{error}</p>
            <button className="button button--secondary" onClick={retry}>Try again</button>
          </div>
        ) : loading ? (
          <p className="directory-empty" role="status">Loading compensation…</p>
        ) : <CompensationTable report={report} />}
      </section>
    </Workspace>
  );
}
