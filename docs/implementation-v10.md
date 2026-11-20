# ACME Salary Management | v10 same-email HR handover

## What Aditya caught

The Access Admin screen could revoke a departing manager’s access and grant access to an enrolled replacement. It had no way to hand the same HR email to a new person. Aditya used Alex and Harry to show the gap. Alex was leaving the HR role, Harry was taking over, and the organization wanted both managers to use the same HR mailbox in succession. Aditya also pointed out that the admin needed to change the password as part of that handover.

The discussion clarified that replacing Alex means transferring the login to Harry’s employee record. Editing Alex’s name would make his historical actions appear to belong to Harry. The transfer preserves each person’s joining date and salary history, and keeps past salary entries attributed to the person who recorded them.

## How the handover works

1. HR creates an employee profile for Harry if he is new. An existing active employee can be selected directly.
2. Access Admin opens Alex’s login, selects **Transfer HR access**, and looks up Harry by employee number. The screen shows Harry’s name before the admin confirms.
3. The admin sets a temporary password and shares it privately with Harry. In one transaction, Rails removes the login email from Alex’s account, assigns it to Harry’s account, and records the admin, outgoing account, and incoming account in the access audit.
4. Alex’s existing sessions end and his old password and reset links no longer work. Harry signs in with the same HR email and must choose a different password before he can access employee data.

## What we corrected and verified

- **Queued recovery could follow the mailbox.** Password reset jobs previously looked up an account by email when the job ran. After a transfer, a queued request could have resolved to the replacement. Recovery jobs now carry the account ID and access version captured when the request was made. A transfer invalidates queued requests and previously issued links for the old owner.
- **Historical authorship was hard to verify in the UI.** Salary records already referenced the author’s account. We preserved that relationship and added **Recorded by** to the salary timeline so a reviewer can see that Alex’s past entries still belong to him.
- **The first browser check loaded an older React bundle.** Regenerating the precompiled assets exposed the new action. The follow-up Chromium check used an isolated demo database and verified lookup, handover, outgoing sign-out, required password setup after a refresh, and the original salary author.
- **54 Rails tests and 478 assertions passed.** Tests cover admin authorization, replacement eligibility, the old password and sessions, required password setup, historical attribution, and a fresh reset request for the new mailbox owner.

Aditya also asked where **Forgot password?** appears. The link is displayed on sign-in when email delivery is configured. Railway still needs an HTTPS email provider. The admin-issued temporary password flow works independently of email delivery. Coordinate access to the shared inbox with the organization’s email admin before using mailbox-based recovery.

## Incremental commits

| Commit | Change |
| --- | --- |
| `3eb6575` | Added transactional mailbox transfer, access auditing, password setup restrictions, and recovery regression tests. |
| `f338a95` | Added the admin and first-login screens, plus salary author visibility in React. |
