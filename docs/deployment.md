# Deploy the assessment demo

## Railway

Deploy the repository as a single Railway service. Railpack builds React and Rails together, then Puma serves both from one HTTPS origin. The Free plan includes a 0.5 GB persistent volume and a monthly usage allowance. The app can sleep between requests and becomes unavailable if the allowance runs out. See the [Railway Free plan](https://docs.railway.com/pricing/free-plan).

1. Connect this repository to a Railway service using Railpack. Attach a volume at `/data` before the first successful deployment and keep one replica. Set the service settings below. The start command prepares the database after Railway mounts the volume and then starts Puma.
2. Set `RAILS_ENV=production` in the service variables. Generate a Rails secret with `bin/rails secret` and set it as `SECRET_KEY_BASE`. Keep the same value across redeployments.
3. For an assessment instance with synthetic data, set `ACME_SEED_DEMO=1` before the first boot. Set distinct private passwords of 12–72 bytes for `ACME_DEMO_HR_ONE_PASSWORD`, `ACME_DEMO_HR_TWO_PASSWORD`, `ACME_DEMO_ADMIN_ONE_PASSWORD`, `ACME_DEMO_ADMIN_TWO_PASSWORD`, and `ACME_DEMO_REPLACEMENT_PASSWORD`. Rails seeds the empty database during `db:prepare`. If seeding needs a retry, run `bin/rails db:seed` in the running service with those variables set.
4. Generate the public domain in Railway. Check `/up`, sign in as the seeded HR Manager and Access Admin, and verify an edit survives a restart. Share the hosted demo credentials privately.

| Service setting | Value |
| --- | --- |
| Build command | `npm ci --include=dev && npm run build && RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile` |
| Start command | `bin/start-hosted` |
| Health check | `/up` with a 180-second timeout |
| Serverless | Enabled to save usage while idle |

The production recovery flow currently uses SMTP. Railway Free blocks SMTP egress, so keep recovery disabled on that plan until an HTTPS email delivery method is configured. The [operator reset command](../README.md#password-recovery) works without email. See [Railway outbound networking](https://docs.railway.com/networking/outbound-networking).

## Other hosts

Build with `npm ci --include=dev`, `npm run build`, then `RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile`. Run `bin/start-hosted` with `SECRET_KEY_BASE` and `ACME_DATABASE_PATH` set to the SQLite file on persistent storage. Place the service behind an HTTPS reverse proxy. Where SMTP egress is available, configure email as described in [Password recovery](../README.md#password-recovery).
