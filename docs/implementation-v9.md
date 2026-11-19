# ACME Salary Management | v9 password recovery and hosted assessment

The assessment release went live on Railway on 20 November 2026. Rails serves the React app and API over the same HTTPS origin. The hosted database contains 10,000 synthetic employee records and their annual salary histories. [Live demo](https://acme-web-production-29a96927.up.railway.app/) · [54-second walkthrough](acme-assessment-demo.mp4)

## Decisions from the review

| What Aditya raised | How it shaped the release |
| --- | --- |
| What happens if an HR Manager or Access Admin forgets a password? Can we use Devise? | Added Devise for password verification and recovery while retaining the existing Rails session and role checks. |
| Can we deploy the assessment without paying for hosting? Is Render PostgreSQL free? | Reviewed how each free service runs Rails and stores data, then chose Railway so reviewer edits could survive a restart without changing database adapters. |
| Can we use my two emails to try the hosted roles? | Linked the two requested logins to distinct synthetic employee profiles. Created separate reviewer logins so the assessment team can exercise both roles. |

## Authentication and recovery

The [Devise migration](../db/migrate/20261119020000_move_hr_accounts_to_devise.rb) moved the existing bcrypt hashes into Devise’s password column. All five existing demo password hashes and account permissions were preserved. The migration added fields for a hashed reset token and its issuance time, with a unique index on the token.

For both roles, Devise issues a one-time link that expires after 30 minutes. Resetting a password revokes existing sessions. Revoking an account’s access also invalidates outstanding reset links, including when an admin later restores access. The recovery request gives the same response for eligible, inactive, and unknown email addresses.

Hosted email recovery is disabled because Railway’s Trial and Free plans block SMTP. Enabling it on Railway requires an HTTPS email provider. The [operator reset command](../README.md#password-recovery) is available for a forgotten demo password. Hosted passwords are managed privately. [Railway outbound networking](https://docs.railway.com/networking/outbound-networking)

## Free hosting evaluation

A free public URL was only part of the requirement. A reviewer also needed to sign in, record a salary change, and find it again after the service restarted. That made persistent storage the deciding factor.

| Option | What we found |
| --- | --- |
| Render Free with SQLite | Runs Rails and serves React over HTTPS. The free web service has an ephemeral filesystem, so a SQLite file on that service can disappear after a restart or redeploy. [Render Free services](https://render.com/docs/free) |
| Render Free with PostgreSQL | Aditya found the free PostgreSQL option in Render’s dashboard. It would persist changes across web service restarts, but the free database expires after 30 days. Using it would also require validating our migrations, bulk import, and compensation queries on PostgreSQL. [Render Free PostgreSQL](https://render.com/docs/free#free-render-postgres) |
| Oracle Cloud Always Free | A VM and persistent block storage could run the existing stack. This route would require managing the VM, reverse proxy, and HTTPS ourselves. Oracle can reclaim idle free instances. [Oracle Always Free resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm) |
| Railway | The Free plan includes a 0.5 GB persistent volume and a public HTTPS URL. One Rails service and one volume fit the demo, and keeping SQLite let us deploy the same database design we had tested locally. The app can sleep between visits and pauses if the free monthly usage allowance is exhausted. [Railway Free plan](https://docs.railway.com/pricing/free-plan) |

We chose Railway after reviewing those trade-offs. The workspace was on trial credit at launch, and we enabled idle sleeping to conserve it.

## Production deployment process

1. **Rehearsed locally in the Rails production environment.** Built React, precompiled Rails assets, and ran the startup sequence against an isolated SQLite file. Verified the seed created 10,000 employees and an edit survived a process restart.
2. **Created the Railway project and connected GitHub.** After Aditya paired the Railway CLI, we created a dedicated project, connected the repository’s `main` branch, and configured one Railpack web service. Railway provides the HTTPS URL, and Puma serves both the React bundle and the Rails API behind it.
3. **Configured persistent storage and startup.** Mounted the 500 MB volume at `/data` and set the Rails secret and synthetic seed credentials in Railway service variables. The [start script](../bin/start-hosted) checks that the volume is available, runs `db:prepare` against the mounted database, then starts Puma. The first successful deploy seeded the empty database. Subsequent deploys reused the same file.
4. **Opened and verified the hosted app.** Waited for the `/up` health check, then exercised both role workspaces over HTTPS. Created separate personal and reviewer accounts on the synthetic data. The personal account setup used Railway’s deployment controls after the SSH connection could not verify its host key. We removed the temporary enrollment variables, restored the normal startup command, and signed in again.
5. **Published the handoff.** Added the live URL and walkthrough to the README. The [deployment guide](deployment.md) records the build, startup, health check, and idle-sleep settings used on Railway.

## Challenges during deployment

| Challenge | Resolution |
| --- | --- |
| The new Railway service did not apply the root `railway.json` settings. | Set the build command, start command, and health check directly on the service. Removed the deprecated file and documented the service settings for future deploys. [Railway configuration documentation](https://docs.railway.com/infrastructure-as-code#iac-vs-config-as-code) |
| The Railway build stopped at `esbuild: not found`. | The custom build ran after development dependencies had been pruned. Added `npm ci --include=dev` before `npm run build`, then precompiled the Rails assets. The next build passed the health check and served the compiled React bundle. |
| The SQLite volume is available at runtime. | Ran database preparation in the start script after the volume mounted. Proved it used the persistent file by making an access change, redeploying, and checking the same account afterward. [Railway volume mounting](https://docs.railway.com/volumes#volume-availability) |
| The first browser sign-in check timed out during a redeploy. | Waited for the final deployment to pass its health check, then repeated the Chromium check. Sign-in and the compensation report loaded successfully. Idle sleeping can also delay a first visit, which the README now calls out. |

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
