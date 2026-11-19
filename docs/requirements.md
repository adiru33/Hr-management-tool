# ACME Salary Management | v1 requirements

## Goal

Give ACME’s HR manager a web application to manage annual base salaries for 10,000 employees across multiple countries and answer questions about how ACME pays people. Replace routine spreadsheet lookups, salary updates, and basic compensation reporting.

## Scope and HR workflow

1. **Find employees and manage job roles.** HR signs in and searches the paginated directory by name or employee ID, with filters for country, department, and job role. HR can create and rename job roles and assign one current role per employee.
2. **Review and update salary.** The employee’s salary timeline starts with their joining salary. Each later change shows its effective date, previous and new salary, and the amount and percentage change when the currency is the same. For a currency change, show both amounts and currencies and omit the calculated change. HR records a positive amount, currency, and effective date. The system retains who recorded it and when. Each employee has at most one record per effective date. A future entry appears as scheduled and becomes current on its effective date.
3. **Download an employee record.** From the employee page, HR exports a CSV with employee ID, name, country, department, current job role, and one row per salary entry, including its effective date, currency, salary amount, and change figures where applicable. Scheduled entries are identified.
4. **Answer compensation questions.** HR filters the overview by country, department, and job role. It shows headcount with a current salary, mean, and median by currency. Each employee contributes their latest effective salary. For example, HR can find the median annual base salary in INR for Engineering in India.

Only authenticated HR managers can view or change salary data. The deployed assessment demo uses synthetic employee records.

## Deliberately out of scope

- **Spreadsheet import and employee onboarding.** The seed script creates employee profiles and joining salaries. A live migration needs data mapping and reconciliation.
- **Payroll, taxes, bonuses, and equity.** These require country-specific rules or additional compensation models.
- **Exchange-rate conversion and cross-currency totals.** These require a rate source and an agreed rate date.
- **Approval chains, employee self-service, and extra access levels.** These require separate permission and workflow decisions. Job roles describe employees’ positions. Application access belongs to HR managers.
- **Job-role history and salary correction screens.** These require rules for historical assignments and revisions. The first release tracks current job assignments and retains recorded salary entries.

## Acceptance criteria

The deployed Rails and React app uses a relational database and a repeatable seed script for 10,000 synthetic employees. The video demo shows HR reviewing two historical increases, scheduling a raise, exporting a CSV, and filtering compensation by job role. Automated tests cover access, validation, effective dates, change calculations, CSV export, and currency-safe reporting.
