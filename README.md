# ACME Salary Management

Rails serves the React app and will serve the API from the same origin. SQLite stores the application data on disk.

## Local development

Install the Ruby version in `.ruby-version` and Node.js 24. Then run:

```bash
bin/setup --skip-server
bin/dev
```

Open [localhost:3000](http://localhost:3000). After editing React code, run `npm run build` and refresh. Run `bin/rails test` after building the assets. Tests run in a single process by default.

## Design

- [Product requirements](docs/requirements.md)
- [Database design](docs/database-design-v2.md)
