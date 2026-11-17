# SquaresSign on Netlify

This fork uses the existing Sunny Netlify account, without changing its plan.
The project is `squares-sign` (`f0430c0b-fda1-471b-9b95-96a708d1687c`).

Documents use private Netlify Blobs. Every download still passes through the
application's existing authorization checks. Production uses a persistent
`signudoc-production` store; previews use their own isolated store. PDF uploads
are limited to 4 MB on Netlify to fit the function request limit. The upload
screen and server enforce the same limit.

Netlify Database provisions Postgres through `@netlify/database`. The initial
schema is committed under `netlify/database/migrations`; future schema changes
must be added as new migration files. Never edit an applied migration or run
the upstream migration script against this database. Netlify applies the
committed migrations as part of publishing each deployment.

Set these variables through the Netlify environment controls: `STORAGE_DRIVER=netlify`,
`APP_URL`, `BETTER_AUTH_SECRET`, `SETUP_TOKEN`, `CRON_SECRET`, `SUPPORT_EMAIL`,
and `RESEND_API_KEY`. Personal uses standard encrypted variables with all
scopes; account administrators can read their values. Never include secrets
in browser code, snippets, or the repository. `NETLIFY` is reserved by the
platform and must not be set manually. Resend needs a verified sending domain before invitations can
reach recipients. `RESEND_FROM_EMAIL` can be set after domain verification or
managed in the application's organization settings.

Daily maintenance runs at 09:00 UTC and calls the existing protected retention
endpoint for reminders, expiration, and cleanup. The optional upstream backup
to Vercel Blob is not configured for this installation. Netlify's database
backups do not replace a separate backup of the document store.

Deploy only a clean, published main branch using `npm run deploy:netlify` for
a preview, then `npm run deploy:netlify -- --prod` for production. The script
checks the branch, working tree, remote commit, and linked project before
invoking Netlify. No plan upgrades or credit purchases are part of deployment.
Automatic credit purchases were disabled when the installation was prepared.
All sites in this team share its credit allowance.

Review upstream update pull requests for compatibility with the Netlify
adapter, storage driver, and migrations before merging them.
