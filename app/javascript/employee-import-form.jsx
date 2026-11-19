import React, { useEffect, useRef, useState } from "react";

export function EmployeeImportForm({ onUpload, onBack }) {
  const [pending, setPending] = useState(false);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const heading = useRef(null);
  useEffect(() => { heading.current.focus(); }, []);

  async function submit(event) {
    event.preventDefault();
    const file = new FormData(event.currentTarget);
    setPending(true);
    setError(null);
    try {
      setResult(await onUpload(file));
    } catch (failure) {
      setError(failure.status ? {
        message: failure.message,
        rows: failure.details?.rows ?? [],
        count: failure.details?.invalidRows ?? 0,
      } : { message: "Unable to reach the server. Please try again.", rows: [], count: 0 });
    } finally {
      setPending(false);
    }
  }

  return <>
    <div className="workspace-heading">
      <h1 ref={heading} tabIndex={-1}>Import employees</h1>
      <p>Upload a CSV to add employees and their starting annual salaries.</p>
    </div>
    <section className="workspace-card salary-form-card" aria-label="CSV upload">
      {result ? (
        <>
          <p className="workspace-notice" role="status">
            Imported {result.imported.toLocaleString()} {result.imported === 1 ? "employee and starting salary" : "employees and starting salaries"}.
          </p>
          <button className="button button--primary" onClick={onBack}>Back to employees</button>
        </>
      ) : (
        <form className="import-form" onSubmit={submit}>
          <a className="employee-link" href="/templates/employee-import.csv" download>Download sample CSV</a>
          <p className="muted" id="import-help">
            Use UTF-8, the template headers, and existing department and job role names. Limit 10,000 employees and 5 MB per file.
          </p>
          <div className="form-field import-file">
            <label htmlFor="import-file">CSV file</label>
            <input id="import-file" type="file" name="file" accept=".csv,text/csv" aria-describedby="import-help"
              required disabled={pending} onChange={() => setError(null)} />
          </div>
          {error && <div role="alert" className="form-error">
            <p>{error.message}</p>
            {error.rows.length > 0 && <ul className="import-errors">
              {error.rows.map(({ row, message }) => <li key={row}>Row {row}: {message}</li>)}
            </ul>}
            {error.count > error.rows.length && <p>Showing the first {error.rows.length} of {error.count} invalid rows.</p>}
          </div>}
          <div className="button-group form-actions">
            <button className="button button--secondary" type="button" onClick={onBack} disabled={pending}>Cancel</button>
            <button className="button button--primary" type="submit" disabled={pending}>
              {pending ? "Importing…" : "Import employees"}
            </button>
          </div>
        </form>
      )}
    </section>
  </>;
}
