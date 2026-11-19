# ACME Salary Management | v3 implementation milestone

The Rails, React, and SQLite foundation is in place. This milestone turns the [v1 requirements](requirements.md) and [v2 database design](database-design-v2.md) into a working application shell, a tested data model, and a repeatable demo dataset.

## Steps completed

| Commit | What changed |
|---|---|
| `64acc3b` | Set up Rails and SQLite, added a React entry point served by Rails, and verified that the app serves the built React asset. |
| `725e130` | Created the five tables, foreign keys, constraints, and indexes. Added employee, HR account, department, job role, and salary models with tests. |
| `4b7bcca` | Added repeatable seed data for 10,000 synthetic employees across five countries, 29,996 salary records, and two HR accounts. |

## Questions we resolved

| Question | Decision |
|---|---|
| Does an employee have one salary or many? | Each active employee has one current salary and can have many salary records over time. The first row is the joining salary. Each later row stores the full new annual base salary and its effective date. The current salary is the latest row effective as of the date being checked. |
| Can HR see the first and second raises years later? | Yes. The timeline compares each entry with the preceding salary in the same currency. For example, ₹10,00,000 → ₹11,00,000 → ₹12,65,000 shows increases of ₹1,00,000 (10%) and ₹1,65,000 (15%). A currency change displays both amounts and leaves the increase figures blank. |
| Why store annual salary? | ACME needs an employee and compensation management tool. A row represents the employee’s **annual base salary rate** from an effective date, even when the salary changes partway through a year. Month-by-month payroll is out of scope. It would add pay periods, proration, deductions, and country-specific payroll rules. Annual rates support salary history and comparisons without that payroll workload. |
| What happens when someone joins or resigns? | Create the employee and their joining salary together. Resignation applies to any employee. The last working day is inclusive. Afterward, the employee leaves current compensation reports, their history stays available, and salary changes scheduled after departure are marked unapplied. |
| Is the HR manager an employee? Can they change their own salary? | HR managers have employee records and linked HR accounts. The salary model blocks self-edits and records which other HR manager entered a change. Employment dates determine whether an HR account is eligible for access. Session enforcement belongs to the upcoming sign-in workflow. |
| Why use both department and job role? | Department identifies the team, such as Engineering. Job role identifies the position, such as Data Analyst. One role can appear in several departments. HR can use both dimensions in compensation reports. |
| Where does country go? | Each employee has one required `country_code` for their current work country. Each salary row carries its own currency. Reports can filter by country and group salary figures by currency. |
| How will HR get an employee document? | The planned CSV download will include the employee’s details, joining and departure dates, and one row per salary entry. It will use the same timeline and increase calculations as the employee detail page. |
| Why choose SQLite? | The assessment serves one organization and starts with 10,000 employees. SQLite keeps local setup light on a 4 GB machine because it runs inside the application process. The deployment plan uses one app instance and a persistent disk for the database file. |
| Which indexes do we need now? | Employee number is unique. Country, department, and job role have filter indexes. The unique `(employee_id, effective_on)` index supports the latest-salary lookup and prevents two entries for the same employee on the same date. We’ll use query plans to decide whether future directory and reporting queries need additional composite indexes. |

## Verification and next step

All 12 tests passed. They cover the React entry point, atomic hiring, effective dates, resignation, salary changes, self-edit protection, and database constraints. Running the seed twice produced the same row counts. SQLite’s query plan showed that the country filter used the country index and that the latest-salary query used the composite salary index.

The requirements and data-model decisions came from our design review. We used Codex to scaffold the app, turn those decisions into Rails models and tests, and check the resulting SQLite query plans.

The next milestone is the first end-to-end HR workflow. An HR manager signs in, finds an employee, reviews their salary history, and records a raise. CSV export and compensation reporting follow that workflow.
