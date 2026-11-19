import React, { useState } from "react";
import { api } from "./api.js";

export function PasswordRecoveryForm({ token, onBack }) {
  const resetting = token !== undefined;
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  async function submit(event) {
    event.preventDefault();
    const params = Object.fromEntries(new FormData(event.currentTarget));
    setError("");
    setSaving(true);
    try {
      const result = await api("/api/password_reset", {
        method: resetting ? "PATCH" : "POST",
        body: resetting ? { ...params, token } : params,
      });
      setMessage(result.message);
    } catch (failure) {
      setError(failure.status ? failure.message : "Unable to reach the server. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  const back = onBack
    ? <button className="sign-in__help-action" type="button" onClick={onBack}>Back to sign in</button>
    : <a className="sign-in__help-action" href="/">Back to sign in</a>;

  if (message) return <><p className="workspace-notice" role="status">{message}</p>{back}</>;
  if (resetting && !token) return <><p className="form-error" role="alert">This link is incomplete. Request a new reset link.</p>{back}</>;

  return <>
    <form className="sign-in__form" onSubmit={submit} onChange={() => setError("")}>
      {resetting ? (
        <>
          <div className="form-field">
            <label htmlFor="new-password">New password</label>
            <input id="new-password" name="password" type="password" autoComplete="new-password" minLength={12}
              maxLength={72} required />
          </div>
          <div className="form-field">
            <label htmlFor="confirm-password">Confirm password</label>
            <input id="confirm-password" name="password_confirmation" type="password" autoComplete="new-password"
              minLength={12} maxLength={72} required />
          </div>
        </>
      ) : (
        <div className="form-field">
          <label htmlFor="recovery-email">Work email</label>
          <input id="recovery-email" name="email" type="email" autoComplete="email" autoCapitalize="none"
            spellCheck={false} required />
        </div>
      )}
      {error && <p className="form-error" role="alert">{error}</p>}
      <button className="sign-in__submit" type="submit" disabled={saving}>
        {saving ? "Submitting…" : resetting ? "Reset password" : "Send reset link"}
      </button>
    </form>
    {back}
  </>;
}
