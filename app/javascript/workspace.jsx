import React, { useState } from "react";

export function Workspace({ account, onSignOut, children }) {
  const [signingOut, setSigningOut] = useState(false);
  const [signOutError, setSignOutError] = useState("");

  async function signOut() {
    setSigningOut(true);
    setSignOutError("");
    try {
      await onSignOut();
    } catch {
      setSignOutError("Unable to sign out. Please try again.");
    } finally {
      setSigningOut(false);
    }
  }

  return (
    <div className="workspace">
      <header className="workspace-header">
        <div className="workspace-header__inner">
          <div className="workspace-brand"><strong>ACME</strong><span>Salary Management</span></div>
          <div className="workspace-account">
            <span>{account.name}</span>
            <button className="button button--secondary" onClick={signOut} disabled={signingOut}>
              {signingOut ? "Signing out…" : "Sign out"}
            </button>
          </div>
        </div>
      </header>
      <main className="workspace-main">
        {signOutError && <p className="form-error" role="alert">{signOutError}</p>}
        {children}
      </main>
    </div>
  );
}
