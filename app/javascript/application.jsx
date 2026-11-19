import React, { useCallback, useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import { EmployeeWorkspace } from "./employee-workspace.jsx";
import { CompensationWorkspace } from "./compensation-workspace.jsx";
import { AccessWorkspace } from "./access-workspace.jsx";
import { api } from "./api.js";

function HrWorkspace(props) {
  const [section, setSection] = useState("employees");
  const View = section === "compensation" ? CompensationWorkspace : EmployeeWorkspace;
  return <View {...props} navigation={{ section, onChange: setSection }} />;
}

const workspaces = new Map([["hr_manager", HrWorkspace], ["access_admin", AccessWorkspace]]);

function SignIn({ onSignIn }) {
  const [passwordVisible, setPasswordVisible] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState("");

  async function signIn(event) {
    event.preventDefault();
    setError("");
    setPending(true);
    const form = new FormData(event.currentTarget);
    try {
      const { account } = await api("/api/session", {
        method: "POST", body: { email: form.get("email"), password: form.get("password") },
      });
      onSignIn(account);
    } catch (failure) {
      setError(failure.status ? failure.message : "Unable to reach the server. Please try again.");
    } finally {
      setPending(false);
    }
  }

  return (
    <main className="sign-in">
      <header className="sign-in__brand">
        <div className="sign-in__brand-name">ACME</div>
        <div className="sign-in__product">
          <p>People Operations</p>
          <h1>Salary Management</h1>
        </div>
      </header>

      <section className="sign-in__panel" aria-labelledby="sign-in-heading">
        <div className="sign-in__content">
          <h2 id="sign-in-heading">Sign in</h2>
          <p className="sign-in__intro">Use your ACME account.</p>

          <form className="sign-in__form" onSubmit={signIn} onChange={() => setError("")}>
            <div className="form-field">
              <label htmlFor="email">Work email</label>
              <input id="email" name="email" type="email" autoComplete="username" autoCapitalize="none"
                spellCheck={false} required />
            </div>

            <div className="form-field">
              <label htmlFor="password">Password</label>
              <div className="password-field">
                <input id="password" name="password" type={passwordVisible ? "text" : "password"}
                  autoComplete="current-password" autoCapitalize="none" spellCheck={false} required />
                <button className="password-field__toggle" type="button"
                  onClick={() => setPasswordVisible(!passwordVisible)}>
                  {passwordVisible ? "Hide password" : "Show password"}
                </button>
              </div>
            </div>

            {error && <p className="form-error" role="alert">{error}</p>}
            <button className="sign-in__submit" type="submit" disabled={pending}>
              {pending ? "Signing in…" : "Sign in"}
            </button>
          </form>

        </div>
      </section>
    </main>
  );
}

function App() {
  const [account, setAccount] = useState(undefined);
  const [connectionError, setConnectionError] = useState("");
  const [attempt, setAttempt] = useState(0);

  const refreshSession = useCallback(() => {
    setConnectionError("");
    setAccount(undefined);
    setAttempt((previous) => previous + 1);
  }, []);

  const accountRole = account?.role;
  const handleSessionError = useCallback((failure) => {
    if (failure.status === 401) {
      setAccount(null);
      return true;
    }
    if (failure.code === "wrong_role" && failure.accountRole !== accountRole) {
      refreshSession();
      return true;
    }
    return false;
  }, [accountRole, refreshSession]);

  useEffect(() => {
    const controller = new AbortController();
    api("/api/session", { signal: controller.signal })
      .then(({ account }) => { if (!controller.signal.aborted) setAccount(account); })
      .catch(() => {
        if (!controller.signal.aborted) setConnectionError("Unable to reach the server.");
      });
    return () => controller.abort();
  }, [attempt]);

  async function signOut() {
    await api("/api/session", { method: "DELETE" });
    setAccount(null);
  }

  if (account === undefined) {
    return <main className="workspace-main">
      {connectionError ? <>
        <p role="alert">{connectionError}</p>
        <button className="button button--secondary" onClick={refreshSession}>Try again</button>
      </> : <p role="status">Checking your session…</p>}
    </main>;
  }

  if (!account) return <SignIn onSignIn={setAccount} />;

  const Workspace = workspaces.get(accountRole);
  if (!Workspace) {
    return <main className="workspace-main">
      <p role="alert">Your workspace could not be identified.</p>
      <button className="button button--secondary" onClick={refreshSession}>Try again</button>
    </main>;
  }

  return <Workspace account={account} onSignOut={signOut} onSessionError={handleSessionError} />;
}

createRoot(document.getElementById("app")).render(<App />);
