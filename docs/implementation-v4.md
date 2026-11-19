# ACME Salary Management | v4 sample data and verification

## How we create the sample data

Run `bin/rails db:seed` in development. The [seed implementation](../db/demo_seed.rb) creates **10,000 synthetic employees across five countries**, including two employees with HR accounts. It uses predictable employee numbers, joining dates, and salary amounts so reviewers can reproduce the same scenarios on a fresh database.

The [v3 seed](implementation-v3.md) typically gave employees a joining salary, a first-year raise, and a fourth-year raise. During review we asked whether the timeline should show raises each year. Commit `b984ca5` adds a raise on each completed work anniversary through **19 November 2026** or the employee’s last working day, whichever comes first. A raise on the last working day is included. Each record stores the full annual base salary effective on that date. The anniversary schedule generates sample data. HR enters salary changes manually in the product workflow.

The seed inserts employees in batches of 500. The unique employee number and salary effective-date indexes let it fill gaps on reruns while preserving existing records. The database contains **82,790 salary records**, including **10,000 joining salaries** and **72,790 raises**. Effective dates run from 1 January 2017 through 19 November 2026.

## Automated test cases

Run `npm run build` and then `bin/rails test`. The suite passed with **14 tests and 52 assertions**.

| # | Test case |
|---:|---|
| 1 | Rails serves the React entry point and compiled asset. |
| 2 | Hiring creates the starting salary on the joining date and records which HR manager entered it. |
| 3 | An invalid starting salary rolls back the employee and salary together. |
| 4 | A scheduled salary becomes current on its effective date, and earlier raises still show their amount and percentage. |
| 5 | A currency change leaves the increment amount and percentage blank. |
| 6 | Resignation preserves salary history, includes the last working day, and leaves later entries unapplied. |
| 7 | HR account eligibility follows employment dates, including the last working day. |
| 8 | An HR manager cannot change their own salary. Another HR manager can record the change. |
| 9 | SQLite rejects duplicate employee and effective-date pairs and invalid salary amounts. |
| 10 | Saved salary entries are read-only through the model. |
| 11 | Amount conversion respects currency precision, including currencies with zero decimal places. |
| 12 | The employee model rejects unsupported work countries and a last working day before joining. |
| 13 | The seed includes every completed anniversary through the demo date, preserves the original first- and fourth-year amounts, and increases the salary each year. |
| 14 | The seed includes the anniversary on an employee’s last working day and stops there. |

Test source files are the [React smoke test](../test/integration/home_test.rb), [compensation model tests](../test/models/compensation_test.rb), and [seed history tests](../test/models/demo_seed_test.rb).

## Database verification

- Upgraded the existing SQLite database from **29,996 to 82,790** salary records and compared the original rows before and after. All original rows were intact.
- Checked all 10,000 employees for a complete anniversary timeline through the applicable cutoff. Sample employee `DEMO-00001` has nine salary records, one on 1 January of each year from 2018 through 2026.
- Ran the seed again and confirmed that the totals stayed the same. Initialized a fresh SQLite database and confirmed the same employee, salary, and HR account counts.
- Verified that salary rows in the fresh database were authored by an HR account belonging to a different employee. Checked the SQLite query plans for the country filter and the latest effective salary lookup.
