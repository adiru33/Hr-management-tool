import React, { useEffect, useRef, useState } from "react";

export function FocusHeading({ children, ...props }) {
  const heading = useRef(null);
  useEffect(() => { heading.current.focus(); }, []);
  return <h1 {...props} ref={heading} tabIndex={-1}>{children}</h1>;
}

export function Filter({ field, label, value, options, renderValue = (option) => option, onChange }) {
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

export function Workspace({ account, onSignOut, navigation, children }) {
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
      {navigation && <nav className="workspace-nav" aria-label="HR workspace">
        <div className="workspace-nav__inner">
          {[["employees", "Employees"], ["compensation", "Compensation"]].map(([section, label]) => (
            <button key={section} className="workspace-nav__item"
              aria-current={navigation.section === section ? "page" : undefined}
              onClick={() => navigation.onChange(section)}>{label}</button>
          ))}
        </div>
      </nav>}
      <main className="workspace-main">
        {signOutError && <p className="form-error" role="alert">{signOutError}</p>}
        {children}
      </main>
    </div>
  );
}
