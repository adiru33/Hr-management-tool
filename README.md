# ACME Salary Management

Rails serves the React app and will serve the API from the same origin. SQLite stores the application data on disk.

## Local development

Install the Ruby version in `.ruby-version` and Node.js 24. Then run:

```bash
bin/setup --skip-server
bin/dev
```

Open [localhost:3000](http://localhost:3000). After editing React code, run `npm run build` and refresh. Run `bin/rails test` after building the assets. Tests run in a single process by default.

## Demo data

Run `bin/rails db:seed` to load 10,000 synthetic employees across five countries and two HR accounts. Each salary history starts with the joining salary and includes a raise on each completed work anniversary through 19 November 2026 or the employee’s last working day, whichever comes first. This pattern belongs to the demo data. HR records salary changes manually in the application.

Development setup seeds a fresh database automatically. Re-running the seed fills missing demo entries and keeps existing records intact. Running the demo seed outside development requires `ACME_SEED_DEMO=1` and the two HR passwords in `ACME_DEMO_HR_ONE_PASSWORD` and `ACME_DEMO_HR_TWO_PASSWORD`.

## Design

- [Product requirements](docs/requirements.md)
- [Database design](docs/database-design-v2.md)
- [Implementation milestone and decision log](docs/implementation-v3.md)
