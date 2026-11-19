export class ApiError extends Error {
  constructor(status, data) {
    super(data.error || "Could not complete the request. Please try again.");
    this.status = status;
    this.code = data.code;
    this.accountRole = data.accountRole;
    this.details = data;
  }
}

export async function api(path, { method = "GET", body, signal, responseType } = {}) {
  const headers = { Accept: responseType === "csv" ? "text/csv, application/json" : "application/json" };
  const csrf = document.querySelector('meta[name="csrf-token"]');
  if (method !== "GET" && csrf) headers["X-CSRF-Token"] = csrf.content;
  const multipart = body instanceof FormData;
  if (body && !multipart) headers["Content-Type"] = "application/json";

  const response = await fetch(path, {
    method, headers, signal, credentials: "same-origin",
    body: multipart ? body : body && JSON.stringify(body),
  });
  if (responseType === "csv" && response.ok) return response.blob();
  const data = await response.json().catch(() => ({}));
  if (data.csrfToken && csrf) csrf.content = data.csrfToken;
  if (!response.ok) throw new ApiError(response.status, data);
  return data;
}
