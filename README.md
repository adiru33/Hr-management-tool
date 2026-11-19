# ACME Salary Management

Rails serves the React app and will serve the API from the same origin. SQLite stores the application data on disk.

## Local development

Install the Ruby version in `.ruby-version` and Node.js 24. Then run:

```bash
bin/setup --skip-server
bin/dev
```

Open [localhost:3000](http://localhost:3000). After editing React code, run `npm run build` and refresh. Run `bin/rails test` after building the assets. Tests run in a single process by default.

## Try the HR workflow

In the seeded local development database, sign in as `hr1@acme.example` with the development password `local-acme-hr-one`. Search for `DEMO-00001`, open the employee's salary history, and select **Record salary change**. A salary change with a future effective date appears as **Scheduled**. Saved salary changes are written to SQLite and remain after refresh.

## Demo data

Run `bin/rails db:seed` to load 10,000 synthetic employees across five countries and two HR accounts. Each salary history starts with the joining salary and includes a raise on each completed work anniversary through 19 November 2026 or the employee’s last working day, whichever comes first. This pattern belongs to the demo data. HR records salary changes manually in the application.

Development setup seeds a fresh database automatically. Re-running the seed fills missing demo entries and keeps existing records intact. Running the demo seed outside development requires `ACME_SEED_DEMO=1` and passwords in `ACME_DEMO_HR_ONE_PASSWORD`, `ACME_DEMO_HR_TWO_PASSWORD`, `ACME_DEMO_ADMIN_ONE_PASSWORD`, `ACME_DEMO_ADMIN_TWO_PASSWORD`, and `ACME_DEMO_REPLACEMENT_PASSWORD`.

## HR access administration

Run `bin/rails db:migrate db:seed` to add the Access Admin and candidate accounts to an existing demo database. Sign in locally as `access-admin@acme.example` with `local-acme-access-one`. The backup is `backup-admin@acme.example` with `local-acme-access-two`. The enrolled demo replacement is `replacement.hr@acme.example` with `local-acme-replacement`. The replacement can sign in after an admin grants HR access.

The Access Admin workspace can grant HR access to an enrolled active employee, record an HR manager’s last working day, or revoke HR access immediately. Revocation invalidates existing sessions, including after access is restored. Each admin action records its actor and target. Access Admins have one dedicated role and no salary access. HR managers can manage salaries subject to the self-edit restriction.

A trusted deployment operator enrolls verified employee identities through an interactive terminal. Employees must have a profile before enrollment. Seed credentials are for the local demo.

```bash
bin/rails 'access:enroll[EMPLOYEE_NUMBER,WORK_EMAIL,employee]'
bin/rails 'access:enroll[ADMIN_EMPLOYEE_NUMBER,WORK_EMAIL,access_admin]'
bin/rails 'access:disable_admin[ADMIN_EMPLOYEE_NUMBER]'
```

The enrollment command prompts for the password. Pre-enroll a primary and backup Access Admin so a trusted operator can recover access if a primary admin leaves.

## Design

- [Product requirements](docs/requirements.md)
- [Database design](docs/database-design-v2.md)
- [Implementation milestone and decision log](docs/implementation-v3.md)
- [Sample data and test results](docs/implementation-v4.md)
