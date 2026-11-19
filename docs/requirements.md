# ACME Salary Management | v1 requirements

## Goal

Give ACME’s HR managers a web application to manage employment records and annual base salaries for 10,000 employees across countries, and answer questions about how ACME pays people.

## Scope and HR workflow

1. **Sign in and find employees.** HR searches the paginated directory by name or employee ID and filters by country, department, job role, or employment status. HR managers have employee records like their colleagues. A linked login grants HR permissions only while the manager is employed.
2. **Record joining and resignation.** HR creates an employee profile with a date of joining, country, department, one current job role, and a starting salary effective on the joining date. HR can create, rename, and assign job roles. To record a resignation, HR enters the last working day. Employment runs from the joining date through the last working day, inclusive. Former employees remain searchable with their salary history intact.
3. **Review and update salary.** The timeline shows the joining salary and each change’s effective date, previous salary, new salary, and amount and percentage difference in the same currency. Currency changes show both amounts without a calculated difference. Each entry records a positive amount, currency, effective date, and who entered it and when. Dates are unique per employee and fall within employment. Future entries appear as scheduled. Any existing entries after a recorded last working day are retained and marked as unapplied.
4. **Export an employee CSV.** HR downloads profile details, including joining date and last working day if set, plus one row per salary entry with date, status, currency, amount, and applicable changes.
5. **Review compensation.** The overview shows headcount with a current salary, mean, and median by currency, with country, department, and job role filters. Each active employee contributes their latest effective salary.

## Deliberately out of scope

- **Spreadsheet import.** A live migration needs data mapping and reconciliation. The seed script supplies the demo data.
- **Payroll, taxes, bonuses, and equity.** These require country-specific rules or additional compensation models.
- **Exchange-rate conversion and cross-currency totals.** These require a rate source and an agreed rate date.
- **Approval chains, employee self-service, and extra access levels.** These require separate permission and workflow decisions. Job roles describe employees’ positions. Application access belongs to HR managers.
- **Job-role history and salary correction screens.** These require rules for historical assignments and revisions. The first release tracks current job assignments and retains recorded salary entries.

## Acceptance criteria

The deployed Rails and React app uses a relational database and a repeatable seed script for 10,000 synthetic employees. The video shows HR recording a hire and resignation, reviewing two raises, exporting a CSV, and filtering compensation. Automated tests cover HR access, employment and salary dates, raise calculations, CSV export, and currency-specific reporting.
