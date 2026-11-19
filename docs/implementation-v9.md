# ACME Salary Management | v9 password recovery and hosted assessment

The assessment release went live on Railway on 20 November 2026. Rails serves the React app and API over the same HTTPS origin. The hosted database contains 10,000 synthetic employee records and their annual salary histories. [Live demo](https://acme-web-production-29a96927.up.railway.app/) · [54-second walkthrough](acme-assessment-demo.mp4)

## Decisions from the review

| What Aditya raised | How it shaped the release |
| --- | --- |
| What happens if an HR Manager or Access Admin forgets a password? Can we use Devise? | Added Devise for password verification and recovery while retaining the existing Rails session and role checks. |
| Can we deploy the assessment without paying for hosting? | Compared Render Free and Railway. Render offers a free PostgreSQL database that expires after 30 days. Railway offered persistent storage for our existing SQLite app, so we kept the database and avoided a production-only adapter change. |
| Can we use my two emails to try the hosted roles? | Linked the two requested logins to distinct synthetic employee profiles. Created separate reviewer logins so the assessment team can exercise both roles. |

## Authentication and recovery

The [Devise migration](../db/migrate/20261119020000_move_hr_accounts_to_devise.rb) moved the existing bcrypt hashes into Devise’s password column. All five existing demo password hashes and account permissions were preserved. The migration added fields for a hashed reset token and its issuance time, with a unique index on the token.

For both roles, Devise issues a one-time link that expires after 30 minutes. Resetting a password revokes existing sessions. Revoking an account’s access also invalidates outstanding reset links, including when an admin later restores access. The recovery request gives the same response for eligible, inactive, and unknown email addresses.

Hosted email recovery is disabled because Railway’s Trial and Free plans block SMTP. Enabling it on Railway requires an HTTPS email provider. The [operator reset command](../README.md#password-recovery) is available for a forgotten demo password. Hosted passwords are managed privately. [Railway outbound networking](https://docs.railway.com/networking/outbound-networking)

## Deployment and build fix

- Railway builds from GitHub’s `main` branch with Railpack. A single Puma instance serves the web app. The 500 MB SQLite volume is mounted at `/data`. The [start script](../bin/start-hosted) requires the volume on Railway, runs `db:prepare` after it is mounted, and starts Puma. The first deploy seeded the empty database. Later deploys reused the same file.
- The first Railway build failed with `esbuild: not found`. The custom build step ran after development dependencies had been pruned. Adding `npm ci --include=dev` before the React build restored the build tool. Rails then precompiled the fingerprinted assets and Railway passed the `/up` health check.
- The final build and start commands live in Railway service settings. The [deployment guide](deployment.md) records them so a reviewer can reproduce the setup. The demo launched on trial credit with idle sleeping enabled. The Free plan’s monthly allowance can pause the service if exhausted. [Railway Free plan](https://docs.railway.com/pricing/free-plan)

## Verification

- **51 Rails tests and 421 assertions passed.** The recovery tests cover both roles, token expiry and reuse, access revocation, and signing in after a password reset.
- Verified HTTPS, the React sign-in and compensation screens in Chromium, all 10,000 seeded employee records, salary history and CSV export, and the separation between HR and Access Admin permissions. Both personal and reviewer account pairs could sign in after the final redeploy.
- Granted a synthetic replacement employee HR access, redeployed from GitHub, and confirmed the grant was still active. Revoked the test grant afterward.
- AI helped implement the Devise integration, write deterministic recovery tests, diagnose the Railway build, and record the walkthrough. Aditya drove the recovery, account, and hosting decisions through review questions. The implementation was checked against the seeded database, test suite, and live service.

## Incremental commits

| Commit | Change |
| --- | --- |
| `d083d9c` | Added Devise sign-in, recovery, and tests. |
| `afc83a6` | Added the hosted startup command and persistent SQLite configuration. |
| `127b67d` | Added the walkthrough and documented Railway service settings. |
| `6fa6dbb` | Fixed dependency installation in the Railway build. |
| `20301cd` | Added the verified live demo URL to the README. |
