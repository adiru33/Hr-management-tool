# ACME Salary Management | v7 compensation overview

Commit `cb7de59` adds a Compensation screen for HR. The review question was **“What’s the median annual base salary for Engineering employees in India?”** The screen lets HR combine country, department, and job role filters and shows one result per currency.

## How we designed the report

SQLite selects one current salary per active employee. It takes the latest effective salary on or before the report date. An employee counts through their last working day. Future raises enter the report when they take effect. The [Rails query](../app/queries/compensation_overview.rb) groups salaries by currency, uses integer minor units such as paise and exact fractions for the calculations, then rounds to the nearest minor unit.

| Metric | Meaning |
|---|---|
| **Headcount** | Number of active employees in the filtered group who have a current salary in that currency. |
| **Mean annual salary** | Sum of those annual base salaries divided by headcount. |
| **Median annual salary** | Middle salary after sorting. For an even headcount, average the two middle salaries. |

For India and Engineering, the report showed **500 employees**, a mean of **₹17,18,658.21**, and a median of **₹17,14,388.87** on 19 November 2026. An independent SQLite calculation returned the same values.

## Indexing decision

The existing composite index on `salary_records(employee_id, effective_on)` does the main work. The query plan confirmed that SQLite uses it to look up each employee’s latest effective salary. The employee table has separate indexes for country, department, and job role. The report calculates mean and median from the resulting current salaries within each currency.

We tested an additional employee index on `(country_code, department_id, job_role_id)` on a copy of the 10,000-employee database. The median of 11 warm SQL runs for India and Engineering was **2.87 ms** with the existing indexes and **3.41 ms** with the candidate. With all three filters, it was **1.79 ms** and **1.31 ms**, respectively. The candidate helped one filtered query by less than a millisecond. We kept the existing schema and can revisit the index if representative workloads show a larger gain. An extra index also adds work when importing employees or editing their profiles.

### What changes at 100,000 employees?

We expanded an isolated copy to **100,000 synthetic employees and 827,900 salary records** using the same country, role, and salary-history distribution. These are median SQL fetch times from nine warm runs per configuration, measured locally.

| Report filters | Existing indexes | With the candidate |
|---|---:|---:|
| India and Engineering | 32.20 ms | 37.74 ms |
| India, Engineering, and Software Engineer | 18.50 ms | 11.50 ms |

At this size the composite employee index is a stronger candidate for the three-filter report, which improved by about **38%**. SQLite still scanned the employee table for the unfiltered report in both runs. Use the frequency and end-to-end latency of real reports to decide whether to add the index. If broad reports become slow, profile how much time goes into retrieving and aggregating current salaries before choosing a different optimization.

## Aditya’s prompts and review feedback

These prompts are lightly edited for readability. They show how the project author directed the work and challenged the result during review.

| Prompt or feedback | Result |
|---|---|
| “Build the compensation report first.” | Prioritized the assessment’s pay questions ahead of the remaining export and job-role screens. |
| “We have an issue.” Aditya shared a screenshot of the error in his running app. | Reproduced the failure on the actual review server, restarted Rails to load the new query directory, and verified the report in the same tab. |
| “What do headcount, mean annual salary, and median annual salary mean?” | Added a definition for each metric to the design note, tied to the filtered employees and their currency. |
| “At one lakh employees, would another composite index help?” | Measured the candidate on both dataset sizes and used the query plans and timings to make the indexing decision. |

## Verification

- The report passed on a freshly started test server, but the review server was already running when the new query directory was added. After the restart, the review tab showed all five currency groups. The India and Engineering filter returned the figures from the independent SQLite calculation.
- AI assisted with query design and test implementation. The [integration tests](../test/integration/hr_workflow_test.rb) cover combined filters, even and odd medians, currency grouping, and exclusion of former employees and future salaries. The [access tests](../test/integration/access_management_test.rb) verify the report is restricted to HR. All **40 tests and 265 assertions** passed.
