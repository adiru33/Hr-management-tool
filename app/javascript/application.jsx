import React from "react";
import { createRoot } from "react-dom/client";

function App() {
  return (
    <main>
      <h1>ACME Salary Management</h1>
    </main>
  );
}

createRoot(document.getElementById("app")).render(<App />);
