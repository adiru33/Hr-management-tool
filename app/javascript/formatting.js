export const countryNames = { DE: "Germany", GB: "United Kingdom", IN: "India", JP: "Japan", US: "United States" };
const currencyDigits = { EUR: 2, GBP: 2, INR: 2, JPY: 0, USD: 2 };
const dateFormatter = new Intl.DateTimeFormat("en-GB", { dateStyle: "medium", timeZone: "UTC" });

export function formatDate(date) {
  return dateFormatter.format(new Date(date + "T00:00:00Z"));
}

export function formatSalary(amount, currency, signed = false) {
  const precision = currencyDigits[currency];
  const units = BigInt(amount);
  const digits = (units < 0n ? -units : units).toString().padStart(precision + 1, "0");
  const fraction = precision ? digits.slice(-precision) : "";
  const whole = precision ? digits.slice(0, -precision) : digits;
  const value = `${units < 0n ? "-" : ""}${whole}${fraction ? "." + fraction : ""}`;
  return new Intl.NumberFormat(currency === "INR" ? "en-IN" : "en-US", {
    style: "currency",
    currency,
    minimumFractionDigits: Number(fraction) ? precision : 0,
    signDisplay: signed ? "exceptZero" : "auto",
  }).format(value);
}
