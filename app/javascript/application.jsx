import React, { useState } from "react";
import { createRoot } from "react-dom/client";
import { EmployeePreview } from "./employee-preview.jsx";

function SignIn({ onContinue }) {
  const [passwordVisible, setPasswordVisible] = useState(false);

  function previewSignIn(event) {
    event.preventDefault();
    onContinue();
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
          <p className="sign-in__intro">Use your ACME HR account.</p>

          <form className="sign-in__form" onSubmit={previewSignIn}>
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

            <button className="sign-in__submit" type="submit">Sign in</button>
          </form>

          <p className="sign-in__preview">
            Design preview. Enter any valid sample email and a sample password to continue.
          </p>
        </div>
      </section>
    </main>
  );
}

function App() {
  const [previewOpen, setPreviewOpen] = useState(false);
  return previewOpen
    ? <EmployeePreview onSignOut={() => setPreviewOpen(false)} />
    : <SignIn onContinue={() => setPreviewOpen(true)} />;
}

createRoot(document.getElementById("app")).render(<App />);
