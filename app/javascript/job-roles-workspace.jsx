import React, { useEffect, useRef, useState } from "react";
import { api } from "./api.js";
import { FocusHeading, Workspace } from "./workspace.jsx";

function JobRoleForm({ role, onSave, onCancel }) {
  const input = useRef(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  useEffect(() => { input.current.focus(); }, []);

  async function submit(event) {
    event.preventDefault();
    const name = new FormData(event.currentTarget).get("name");
    setError("");
    setSaving(true);
    try {
      await onSave(role, name);
    } catch (failure) {
      setError(failure.status ? failure.message : "Unable to reach the server. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  return <section className="workspace-card salary-form-card" aria-labelledby="job-role-form-title">
    <h2 id="job-role-form-title">{role.id ? `Rename ${role.name}` : "Create job role"}</h2>
    <form onSubmit={submit}>
      <div className="form-field job-role-name">
        <label htmlFor="job-role-name">Job role name</label>
        <input id="job-role-name" name="name" ref={input} defaultValue={role.name}
          required maxLength={120} disabled={saving} onChange={() => setError("")} />
      </div>
      {error && <p className="form-error" role="alert">{error}</p>}
      <div className="button-group form-actions">
        <button className="button button--secondary" type="button" disabled={saving} onClick={onCancel}>Cancel</button>
        <button className="button button--primary" type="submit" disabled={saving}>{saving ? "Saving…" : "Save job role"}</button>
      </div>
    </form>
  </section>;
}

export function JobRolesWorkspace({ account, navigation, onSignOut, onSessionError }) {
  const [roles, setRoles] = useState(null);
  const [editor, setEditor] = useState(null);
  const [attempt, setAttempt] = useState(0);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  useEffect(() => {
    const request = new AbortController();
    api("/api/job_roles", { signal: request.signal })
      .then(({ roles }) => { if (!request.signal.aborted) setRoles(roles); })
      .catch((failure) => {
        if (!request.signal.aborted && !onSessionError(failure)) {
          setError(failure.status ? failure.message : "Unable to load job roles. Please try again.");
        }
      });
    return () => request.abort();
  }, [attempt, onSessionError]);

  function openEditor(role) {
    setNotice("");
    setEditor(role);
  }

  async function saveRole(role, name) {
    const path = role.id ? `/api/job_roles/${role.id}` : "/api/job_roles";
    try {
      const saved = await api(path, { method: role.id ? "PATCH" : "POST", body: { name } });
      setRoles((current) => [...current.filter((existing) => existing.id !== saved.id), saved]
        .sort((first, second) => first.name.localeCompare(second.name)));
      setNotice(`Job role ${role.id ? "renamed to" : "created:"} ${saved.name}.`);
      setEditor(null);
    } catch (failure) {
      onSessionError(failure);
      throw failure;
    }
  }

  return <Workspace account={account} onSignOut={onSignOut} navigation={navigation}>
    <div className="workspace-heading employee-heading">
      <div>
        <FocusHeading>Job roles</FocusHeading>
        <p>Manage the job titles HR can assign to employees.</p>
      </div>
      <button className="button button--primary" disabled={!roles || Boolean(editor)}
        onClick={() => openEditor({})}>Create job role</button>
    </div>
    {editor && <JobRoleForm key={editor.id ?? "new"} role={editor} onSave={saveRole} onCancel={() => setEditor(null)} />}
    {notice && <p className="workspace-notice" role="status">{notice}</p>}
    <section className="workspace-card" aria-label="Job role list">
      {error ? (
        <div className="directory-empty">
          <p role="alert">{error}</p>
          <button className="button button--secondary" onClick={() => {
            setError("");
            setAttempt((previous) => previous + 1);
          }}>Try again</button>
        </div>
      ) : !roles ? (
        <p className="directory-empty" role="status">Loading job roles…</p>
      ) : roles.length === 0 ? (
        <p className="directory-empty">No job roles have been created.</p>
      ) : (
        <div className="table-scroll">
          <table aria-label="Job roles">
            <thead><tr><th scope="col">Job role name</th><th scope="col">Actions</th></tr></thead>
            <tbody>
              {roles.map((role) => (
                <tr key={role.id}>
                  <th scope="row">{role.name}</th>
                  <td><button className="button button--secondary" aria-label={`Rename ${role.name}`}
                    disabled={Boolean(editor)} onClick={() => openEditor(role)}>Rename</button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  </Workspace>;
}
