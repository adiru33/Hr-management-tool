# ACME Salary Management | v1 requirements

## Goal

Give ACME’s HR manager a web application to manage annual base salaries for 10,000 employees across multiple countries and answer questions about how ACME pays people. Replace routine spreadsheet lookups, salary updates, and basic compensation reporting.

## Scope and HR workflow

1. **Sign in and find an employee.** An HR manager signs in and searches a paginated directory by name or employee ID, with filters for country and department. Employee records are preloaded for v1.
2. **Review and update salary.** The employee page shows their current annual base salary, currency, salary history, and scheduled changes. HR enters a positive amount, selects a currency, and chooses an effective date. The system saves a new record and captures who recorded it and when. Each employee can have one salary record per effective date. The latest record effective on or before the reporting date is current. Future changes appear immediately as scheduled and enter current reporting on their effective date.
3. **Answer compensation questions.** HR filters the compensation overview by country and department and sees the number of employees with a current salary, the mean, and the median within each currency. Each employee contributes at most one current salary. For example, HR can find the median annual base salary in INR for Engineering in India.

Only authenticated HR managers can view or change salary data. The deployed assessment demo uses synthetic employee records.

## Deliberately out of scope

- **Excel or CSV import and employee administration.** The seed script provides the assessment dataset. A live rollout would need a separate migration plan for mapping, validating, and reconciling ACME’s spreadsheets.
- **Payroll, taxes, bonuses, and equity.** These require country-specific rules or additional compensation models. This release focuses on annual base salary.
- **Exchange-rate conversion and cross-currency totals.** These require a rate source and an agreed rate date. Currency-specific reporting gives HR comparable figures without those assumptions.
- **Approval chains, employee self-service, and correction screens.** These add permission and workflow decisions. The initial release supports one HR role and preserves each recorded salary entry.

## Acceptance criteria

The deployed Rails and React application runs against a relational database populated by a repeatable seed script for 10,000 synthetic employees. The demo shows an HR manager finding an employee, scheduling a raise, and answering a compensation question. Automated tests cover access control, salary validation, effective dates, and reporting by currency.
