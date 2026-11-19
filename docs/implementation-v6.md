# ACME Salary Management | v6 employee lifecycle and CSV import

This milestone builds on the [v5 HR workflow](implementation-v5.md). HR can now add employees, edit their profiles, record departures, and import new hires with starting salaries.

## Steps completed

| Commit | What changed |
|---|---|
| `cb8c954` | Added employee creation, profile editing, and departure in React and Rails. Hiring saves the employee and starting annual salary in one transaction. Profile edits preserve the employee number, joining date, and salary history. Departure records the last working day and keeps historical salaries visible. |
| `73dc5b7` | Added the CSV upload screen, a [downloadable sample](../public/templates/employee-import.csv), and row-level validation. A valid upload creates employees and their joining salaries together. If any row fails, the file saves no records. |

## What the project author guided and tested

- The project author approved employee lifecycle management as the next milestone and suggested bulk CSV upload because HR already works with spreadsheets. They asked for an example file showing the expected employee fields. We added a template with three synthetic hires and linked it directly from **Employees → Import CSV**.
- During hands-on review, the project author asked where HR could change the pay of an employee already in the system. We walked through **Employees → open the employee → Record salary change**. The form takes the full new annual amount, currency, and effective date, then adds an entry to the existing history. The CSV serves a separate workflow for new hires and their opening salaries.
- The project author reported testing the milestone thoroughly before approving it for commit. Codex implemented the workflows, checked the edge cases with automated tests, and ran an independent browser walkthrough on a copy of the demo database.

## Issue found during verification

The first 10,000-row HTTP upload timed out while the importer processed each hire individually. We changed it to validate the file first, check existing employee numbers in batches, and insert employee and salary rows in batches of 500 inside one transaction. The database uniqueness constraint still protects against concurrent imports using the same number. The optimized upload imported **10,000 rows in 8.8 seconds** on the isolated local test database, and we read the last employee’s salary back through the API.

## Verification

- **Browser walkthrough.** Created a hire with a starting salary, edited their department and job role, and recorded their departure. The profile showed the former employee’s salary history. Imported all three sample hires, found an imported employee in the directory, and confirmed that re-uploading the file displayed duplicate errors by row.
- **Automated tests.** All **38 tests and 250 assertions** passed. The [HR workflow tests](../test/integration/hr_workflow_test.rb) cover atomic hiring, invalid input, profile edits that preserve history, departure and unapplied future salaries, CSV parsing and permissions, duplicate numbers, complete rollback on errors, and rejection of files over the row limit.
