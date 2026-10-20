# Smart Horeca Owner — first REAL DATA pilot (Android)

## Pilot status
Opt-in only. Neither `Anar044/anarsystem/main` nor `SmartHoreca-Owner/main` is modified.
Existing demo APKs cannot sign in to a real owner account, because they were
built without public Supabase client configuration and with demo mode enabled.

## 1. Prepare isolated backend preview
Backend branch: `Anar044/anarsystem:feature/owner-mobile-readonly-api-v1`.

Use a Cloudflare Pages preview deployment for this exact branch with a verified
D1 binding and the server-side Supabase configuration. Coordinate a controlled,
authorized test account and restaurant. Do not assume the preview automatically
inherits production D1 bindings or secrets.

Open `https://YOUR-VERIFIED-PREVIEW-ORIGIN/api/mobile/v1/health`.
Expected: `{"success":true,"service":"Smart Horeca Owner Mobile API","version":"v1","status":"preview"}`.
If you see a 404 or generic HTML, that preview is not running the new functions.
Never substitute the main website as a quick workaround.

**Important:** Inspect connected D1 bindings before any live calls. Existing
workspace access code may initialize access tables and system role templates.
Do not claim that the backend makes zero metadata writes. The mobile app itself
has no business-data mutation endpoints.

## 2. Configure OWNER APK in the GitHub repository
Go to `Anar044/SmartHoreca-Owner` → Settings → Secrets and variables → Actions.

Repository VARIABLE:
- `SH_OWNER_PILOT_API_BASE_URL`: exact HTTPS origin of the verified Cloudflare
  preview, **without path or trailing query**.

Repository SECRETS (Supabase PUBLIC CLIENT configuration only):
- `SH_OWNER_SUPABASE_URL`: project's Supabase URL.
- `SH_OWNER_SUPABASE_PUBLISHABLE_KEY`: the project's public publishable key.

Do not use the Supabase service-role key, server passwords, upstream iiko
credentials, Cloudflare API tokens or owner account password as these settings.
Even a GitHub secret used as a `--dart-define` is embedded in the Android APK;
therefore ONLY public client values are acceptable.

After configuration, a new push to `feature/approved-ui-foundation` runs CI:
- `Smart-Horeca-Owner-Android-Preview`: existing demo APK;
- `Smart-Horeca-Owner-Android-Pilot`: actual sign-in, demo disabled, targets
  only the configured preview origin.

The feature workflow intentionally does not create an authenticated APK when the
preview origin is unset.

## 3. First small-scope test
- Pilot only one existing owner account and one authorized restaurant.
- Log in using the normal owner credentials **on the device**, never in chat,
  screenshot, log, issue, workflow variable or code.
- Confirm mobile workspace list is accurate and CHAIN department picker lists
  only permitted restaurants.
- First load today's Sales/Checks, compare with website using exact department
  and same `OpenDate.Typed` dates, currency and net/gross definitions.
- Test shift list/detail; a missing department or payment split must be shown
  as unavailable, not invented or mixed with another restaurant's transactions.
- Test a second authorized restaurant, then two combined, matching the website.
- Verify API rejects missing/expired tokens and wrong workspace/department;
  check via authorized test accounts only, never by trying others' tokens.
- Confirm no business writes are possible from mobile.
- If a discrepancy is observed, preserve only non-sensitive response codes,
  timestamps, report identifiers and a redacted screenshot.

## 4. Gates still to pass
- Validate actual CHAIN server field mappings; `shifts.js` deliberately fails
  closed if cash shift has no verifiable restaurant identifier.
- Server-side access isolation, status of workspace and membership, date
  boundary/timezone checks, API rate limits and any preview D1 side effects.
- Real stock balances, checks/receipt details, standalone reports, and AI
  mobile adapters are not yet complete.
- Golden screenshot parity in Light/Dark on actual device.
- A pilot is NOT a production release. Keep feature branches and draft PRs.
