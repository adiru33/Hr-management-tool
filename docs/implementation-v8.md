# ACME Salary Management | v8 CSV export and job role management

This version documents the employee CSV export that followed the [v7 compensation report](implementation-v7.md) and completes the planned job role workflow.

| Commit | What changed |
|---|---|
| `7ee58dc` | Added **Download CSV** to the employee salary history. Rails uses the same timeline for the screen and the export. |
| `b362a8b` | Added the **Job roles** screen and HR-only endpoints for creating and renaming job titles. |

## Employee CSV export

From an employee’s profile, HR can download their employee number, name, country, department, job role, joining date, and last working day. The file has one row per salary entry, newest first. Each row includes the effective date, status, annual base salary and currency, prior annual base salary and currency, and change amount and percentage where applicable. The status can be Current, Historical, Scheduled, or Unapplied. When the currency changes, both salaries are included and the change fields stay blank.

The [shared timeline](../app/services/employee_salary_timeline.rb) gives the API and [CSV generator](../app/services/employee_salary_csv.rb) the same statuses and percentage rounding. The download preserves currency precision, includes a UTF-8 marker for spreadsheet readers, and prefixes formula-like profile text with a visible text label. Rails checks for an active HR session and serves the download with `Cache-Control: no-store`.

## HR-only job roles

Aditya specified that only HR should create job roles. The same permission applies to renaming, and Rails enforces it on every job role endpoint. Job roles are titles such as Software Engineer. Access Admin and HR Manager permissions are tied to login accounts.

Renaming changes the title on the existing role record. Employees reference the role’s ID, so their assignments carry through to profiles, employee forms, directory filters, and the compensation report. The existing database constraint enforces unique names, and Rails rejects blanks and duplicates that differ only by case.

## Review and verification

- Downloaded `DEMO-00001` in the browser and compared all nine CSV rows with the salary timeline. Dates, amounts, currencies, statuses, and raises matched.
- Created a new role and renamed Software Engineer on an isolated copy of the demo database. Asha Shah retained her assignment and the renamed title was available in the directory and compensation filters.
- When Aditya reported that the create option was missing, the open browser tab still had the previous menu. Refreshing it exposed **Job roles** next to **Compensation**. The new page and **Create job role** control were verified on the review server.
- AI assisted with implementation and test design. The automated suite covers CSV accuracy, active-HR authorization, role creation and duplicate names, and rename behavior across features. **46 tests and 335 assertions passed.**

The remaining assessment deliverables are the deployed synthetic-data demo, end-to-end verification of that deployment, and the walkthrough video.
