import React, { useEffect, useRef, useState } from "react";
import { api } from "./api.js";
import { NewPasswordFields } from "./password-recovery.jsx";
import { Workspace } from "./workspace.jsx";

function AccessStatus({ account }) {
  const className = account.status === "Active" ? "status-tag status-tag--active" : "status-tag";
  return <span className={className}>{account.status}</span>;
}

function TransferHrForm({ account, onUpdate, onCancel, onSessionError }) {
  const [number, setNumber] = useState("");
  const [candidate, setCandidate] = useState(null);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState("");
  const search = useRef(null);
  useEffect(() => { if (!candidate) search.current.focus(); }, [candidate]);

  async function submit(event) {
    event.preventDefault();
    const fields = Object.fromEntries(new FormData(event.currentTarget));
    setPending(true);
    setError("");
    try {
      if (candidate) {
        await onUpdate({ ...fields, operation: "transfer", employee_number: candidate.number });
      } else {
        const query = new URLSearchParams({ employee_number: number });
        setCandidate(await api(`/api/access_accounts/${account.id}/transfer_candidate?${query}`));
      }
    } catch (failure) {
      if (!onSessionError(failure)) {
        setError(failure.status ? failure.message : "Unable to reach the server. Please try again.");
      }
    } finally {
      setPending(false);
    }
  }

  return <section className="workspace-card salary-form-card access-transfer" aria-labelledby="transfer-heading">
    <h2 id="transfer-heading">Transfer HR access</h2>
    <p>Keep {account.email} and assign it to a different employee. {account.name} will lose access immediately.</p>
    <form className="access-transfer__form" onSubmit={submit} onChange={() => setError("")}>
      {candidate ? <>
        <p><strong>Incoming HR Manager</strong><br />{candidate.name} · {candidate.number}</p>
        <p>Share the temporary password privately. {candidate.name} must change it before opening the HR workspace.</p>
        <NewPasswordFields label="Temporary password" prefix="transfer" disabled={pending} />
      </> : <div className="form-field">
        <label htmlFor="replacement-number">Replacement employee number</label>
        <input id="replacement-number" ref={search} value={number} onChange={(event) => setNumber(event.target.value)}
          maxLength={50} disabled={pending} required />
      </div>}
      {error && <p className="form-error" role="alert">{error}</p>}
      <div className="button-group">
        <button className="button button--secondary" type="button" disabled={pending} onClick={onCancel}>Cancel</button>
        {candidate && <button className="button button--secondary" type="button" disabled={pending} onClick={() => {
          setCandidate(null);
          setError("");
        }}>Change employee</button>}
        <button className="button button--primary" type="submit" disabled={pending}>
          {pending ? "Please wait…" : candidate ? "Confirm transfer" : "Find employee"}
        </button>
      </div>
    </form>
  </section>;
}

function AccessAccount({ account, transferNotice, onUpdate, onBack, onSessionError }) {
  const [pending, setPending] = useState(false);
  const [transferring, setTransferring] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const heading = useRef(null);
  useEffect(() => heading.current.focus(), []);

  async function update(operation, lastWorkingOn) {
    setPending(true);
    setMessage("");
    setError("");
    try {
      await onUpdate({
        operation,
        ...(lastWorkingOn && { last_working_on: lastWorkingOn }),
      });
      setMessage({
        grant: "HR access granted.",
        revoke: "HR access revoked.",
        record_departure: "Last working day recorded.",
      }[operation]);
    } catch (failure) {
      if (!onSessionError(failure)) {
        setError(failure.status ? failure.message : "Unable to reach the server. Please try again.");
      }
    } finally {
      setPending(false);
    }
  }

  return (
    <>
      {!transferring && <button className="back-link" onClick={onBack} disabled={pending}>← Back to HR access</button>}
      <div className="workspace-heading">
        <h1 ref={heading} tabIndex={-1}>{account.name}</h1>
        <p>{account.number}{account.email && ` · ${account.email}`}</p>
      </div>
      {transferNotice && <p className="workspace-notice" role="status">{transferNotice}</p>}
      {transferring ? <TransferHrForm account={account} onUpdate={onUpdate} onCancel={() => setTransferring(false)}
        onSessionError={onSessionError} /> : <section className="workspace-card salary-form-card" aria-labelledby="access-heading">
        <h2 id="access-heading">HR access</h2>
        <p><AccessStatus account={account} /></p>
        <div className="button-group access-actions">
          {account.canGrant && <button className="button button--primary" disabled={pending}
            onClick={() => update("grant")}>Grant HR access</button>}
          {account.accessEnabled && <button className="button button--secondary" disabled={pending}
            onClick={() => update("revoke")}>Revoke access now</button>}
          {account.canTransfer && <button className="button button--secondary" disabled={pending}
            onClick={() => setTransferring(true)}>Transfer HR access</button>}
        </div>
        {account.canRecordDeparture && (
          <form className="access-departure" onSubmit={(event) => {
            event.preventDefault();
            update("record_departure", new FormData(event.currentTarget).get("lastWorkingOn"));
          }}>
            <div className="form-field">
              <label htmlFor="last-working-on">Last working day</label>
              <input id="last-working-on" type="date" name="lastWorkingOn" min={account.joinedOn} max="9999-12-31"
                required defaultValue={account.lastWorkingOn ?? ""} disabled={pending} />
            </div>
            <button className="button button--primary" type="submit" disabled={pending}>Record departure</button>
          </form>
        )}
        {message && <p className="workspace-notice" role="status">{message}</p>}
        {error && <p className="form-error" role="alert">{error}</p>}
      </section>}
    </>
  );
}

export function AccessWorkspace({ account, onSignOut, onSessionError }) {
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [result, setResult] = useState(null);
  const [selected, setSelected] = useState(null);
  const [transferNotice, setTransferNotice] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    if (selected) return;
    const request = new AbortController();
    const query = new URLSearchParams({ search, page });
    const timer = setTimeout(async () => {
      try {
        const data = await api(`/api/access_accounts?${query}`, { signal: request.signal });
        if (!request.signal.aborted) setResult(data);
      } catch (failure) {
        if (!request.signal.aborted) {
          if (!onSessionError(failure)) setError(failure.status ? failure.message : "Unable to reach the server. Please try again.");
        }
      } finally {
        if (!request.signal.aborted) setLoading(false);
      }
    }, 150);
    return () => {
      clearTimeout(timer);
      request.abort();
    };
  }, [search, page, attempt, selected, onSessionError]);

  function startLoading() {
    setLoading(true);
    setError("");
  }

  async function update(body) {
    const updated = await api(`/api/access_accounts/${selected.id}`, { method: "PATCH", body });
    if (body.operation === "transfer") setTransferNotice(`HR access transferred to ${updated.name}.`);
    setSelected(updated);
  }

  const currentPage = result?.page ?? 1;

  return (
    <Workspace account={account} onSignOut={onSignOut}>
      {selected ? (
        <AccessAccount key={selected.id} account={selected} onUpdate={update} transferNotice={transferNotice}
          onSessionError={onSessionError} onBack={() => { startLoading(); setSelected(null); setTransferNotice(""); }} />
      ) : (
        <>
          <div className="workspace-heading">
            <h1>HR access</h1>
            <p>Manage HR permissions for enrolled employee accounts.</p>
          </div>
          <section className="workspace-card" aria-label="HR access accounts">
            <div className="access-search form-field">
              <label htmlFor="access-search">Search accounts</label>
              <input id="access-search" type="search" placeholder="Name, employee number, or email"
                value={search} onChange={(event) => { startLoading(); setPage(1); setSearch(event.target.value); }} />
            </div>
            {error ? (
              <div className="directory-empty">
                <p role="alert">{error}</p>
                <button className="button button--secondary"
                  onClick={() => { startLoading(); setAttempt((previous) => previous + 1); }}>Try again</button>
              </div>
            ) : loading ? (
              <p className="directory-empty" role="status">Loading accounts…</p>
            ) : result?.accounts.length ? (
              <div className="table-scroll">
                <table aria-label="HR access accounts">
                  <thead><tr><th scope="col">Employee</th><th scope="col">Work email</th><th scope="col">HR access</th></tr></thead>
                  <tbody>
                    {result.accounts.map((entry) => (
                      <tr key={entry.id}>
                        <th scope="row">
                          <button className="employee-link" onClick={() => setSelected(entry)}>{entry.name}</button>
                          <span className="muted employee-number">{entry.number}</span>
                        </th>
                        <td>{entry.email ?? "—"}</td>
                        <td><AccessStatus account={entry} /></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : <p className="directory-empty">No enrolled accounts match your search.</p>}
            {result && result.total > result.pageSize && (
              <div className="directory-footer">
                <span className="muted">Page {currentPage} of {Math.ceil(result.total / result.pageSize)}</span>
                <div className="button-group">
                  <button className="button button--secondary" disabled={loading || currentPage === 1}
                    onClick={() => { startLoading(); setPage(currentPage - 1); }}>Previous</button>
                  <button className="button button--secondary" disabled={loading || currentPage * result.pageSize >= result.total}
                    onClick={() => { startLoading(); setPage(currentPage + 1); }}>Next</button>
                </div>
              </div>
            )}
          </section>
        </>
      )}
    </Workspace>
  );
}
