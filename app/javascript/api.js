export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export async function api(path, { method = "GET", body, signal } = {}) {
  const headers = { Accept: "application/json" };
  const csrf = document.querySelector('meta[name="csrf-token"]');
  if (method !== "GET" && csrf) headers["X-CSRF-Token"] = csrf.content;
  if (body) headers["Content-Type"] = "application/json";

  const response = await fetch(path, {
    method, headers, signal, credentials: "same-origin",
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await response.json().catch(() => ({}));
  if (data.csrfToken && csrf) csrf.content = data.csrfToken;
  if (!response.ok) throw new ApiError(response.status, data.error || "Could not complete the request. Please try again.");
  return data;
}
