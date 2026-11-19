# ACME Salary Management | v5 HR workflow and access handover

This milestone connects the React screens to the Rails and SQLite foundation from [v3](implementation-v3.md) and uses the [v4 sample dataset](implementation-v4.md). It also adds an Access Admin workspace so the organization can hand over HR access when a manager leaves.

## How the work evolved

| Commit | What changed |
|---|---|
| `d73b5e6` | Built a clickable React prototype for sign-in, employee search, salary history, and recording a salary change. Used a small subset of synthetic records to review the interaction before wiring up the API. |
| `a1ec2fd` | Connected the sign-in form to Rails. Rails verifies the password and employment eligibility, starts a session, and checks CSRF tokens for writes. |
| `38e8f26` | Connected employee search, filters, pagination, and salary history to SQLite. Rails queries the full directory, returns 25 employees per page, and determines current and scheduled salary from effective dates. |
| `07ef07d` | Connected the salary change form to a Rails write endpoint. Rails validates the amount, currency, and effective date, blocks self-edits and duplicate dates, and records the acting HR manager. The change remains after refresh. |
| `15d4570` | Added roles, the Access Admin workspace, HR access audit events, and the two account migrations. |
| `9a0b132` | Made React recheck the session and open the correct workspace when its current screen expects a different role. |

## How your review changed the implementation

| What you asked or pointed out | What we implemented or clarified |
|---|---|
| Review the React design before connecting Rails, and explain the workflow as we build. | We delivered the sign-in preview first, then the directory, profile, and salary form. We shared local credentials and a walkthrough so you could review the experience with `DEMO-00001` before we wired it to SQLite. |
| Which create and update forms exist? Connect the salary workflow first and do employee profile forms later. | We connected the existing **Record salary change** form to Rails. Hiring and profile-edit screens remain a separate milestone. |
| Should production use Devise or JWT? What if React and Rails are deployed separately? | We kept the working Rails cookie session for the current same-origin app. React and Rails can run on different hosts behind one public origin. For real salary data, we discussed server-side session revocation and company SSO with MFA, or Devise if ACME manages its own passwords. That broader authentication hardening is a separate production decision. |
| Who updates an HR manager’s salary? What happens when the only HR manager resigns? | We kept HR managers linked to employee records. Another HR manager records their salary changes. A separate **Access Admin** can record the departing manager’s last working day, revoke access immediately, and grant HR access to an enrolled replacement. The employee record and salary history stay intact. |
| Why use a Rails enum instead of Rolify? | Each account has one app-wide role. We use Rails’ built-in enum for `employee`, `hr_manager`, and `access_admin`. The controllers enforce those permissions. A trusted operator enrolls the employee identity and sets its initial credential through the terminal. Admins grant access without handling password credentials or gaining salary access. |
| The Employees page showed “HR Manager access is required” while you tried to find the replacement account. | We used your screenshot to check the role and screen separately. Rails was enforcing the correct restriction. React now refreshes its session state when the active role differs from the open workspace, then opens **HR access** for admins or **Employees** for HR managers. |

## Why we added migrations

The original database assumed every login belonged to an HR manager. The handover workflow needs to persist the role, whether access is enabled, and who made access changes. A React-only change would be unable to enforce those decisions across sessions or survive a restart.

1. [Add account access management](../db/migrate/20261119010000_add_account_access_management.rb) adds `role`, `access_enabled`, and `access_version` to `hr_accounts`. It keeps existing accounts enabled as HR managers and retains their IDs, employee links, and salary attribution. It also creates `account_access_events` with foreign keys for the actor and target and records grant, revoke, and departure actions.
2. [Default new accounts to no HR access](../db/migrate/20261119010100_default_new_accounts_to_no_hr_access.rb) changes the defaults for new rows to an enrolled employee with access disabled. That preserves the existing HR accounts from the first migration while requiring an explicit grant for new employees.

Revoking HR access advances the account’s access version. Rails compares the version in the session with the value in SQLite on protected requests, so a session issued before revocation stays invalid even if an admin later restores access. Employment dates also apply on each request. The last working day is inclusive, while immediate revocation takes effect on the next protected request.

## Verification

- **Automated tests.** 30 tests and 178 assertions passed. The [HR workflow tests](../test/integration/hr_workflow_test.rb) cover sign-in, CSRF, pagination, salary history, and validated writes. The [access tests](../test/integration/access_management_test.rb) cover separation of roles, replacement of the sole HR manager, history retention, audit events, and invalidation of old sessions.
- **Browser review.** On separate copies of the demo database, we verified that a scheduled raise survived refresh, an admin could revoke the departing manager and grant access to a replacement, the replacement could view retained history, and an open tab could recover after the session role changed in another tab.
- **Collaboration.** You chose the React-first sequence, identified the single-HR handover problem, and surfaced the wrong-workspace behavior during review. Codex translated that feedback into incremental changes, migrations, and tests, then checked the results against the seeded dataset.
