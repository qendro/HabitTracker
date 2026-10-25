# Validation record

Local environment: AMD64 Debian 13 container, Elixir 1.19.5 / OTP 28,
PostgreSQL 17.6, ImageMagick 7.1.1 with native libheif HEIC codecs, Chromium via
Playwright. These checks say nothing about Oracle capacity or actual iOS behavior.

Passed:

- `mix format --check-formatted`.
- `mix compile --warnings-as-errors` (development and test environments).
- `mix test`: 29 tests, 0 failures. Includes owned CRUD/direct routes, multiple same-day
  entries, null versus zero, invalid details/kinds/zones/times, clock skew, backdating,
  DST 23/25-hour days, retry IDs, stale edits and restored drafts, ID-tied pagination,
  private attachment URLs, upload through LiveView, spoofed content, byte/pixel/count
  limits, HEIC decoding, metadata stripping, failed processing/retry, deletion/orphan
  cleanup, Unicode ZIP/CSV exports and owner/password/session boundaries.
- `mix assets.build`.
- Fresh migrations in the local development/test databases. Applied original
  migrations remain byte-for-byte unchanged; the new additive migration ran after
  them. No resets, destructive legacy-table changes or habit-data conversion.
- Local HTTP health endpoint returned 200 with a working database.
- `test/browser/smoke.cjs` in Chromium at 390 × 844: login, photo-free stool logging,
  zero-valued check-in, ratings/text draft recovery after reload, draft clearing on
  server-confirmed save and logout, settings, unsaved-navigation confirmation,
  offline/reconnect banner and no horizontal layout overflow. Browser JS errors: none.

Repeat the browser workflow against an **isolated local test account**. It creates
sample entries; do not use personal/production data. Install Playwright outside the
repository if needed and point `NODE_PATH` to that installation. Chromium must be
available at `/usr/bin/chromium`.

```sh
JOURNAL_URL=http://localhost:4000 \
JOURNAL_EMAIL=YOUR_LOCAL_TEST_EMAIL \
JOURNAL_PASSWORD=YOUR_LOCAL_TEST_PASSWORD \
node test/browser/smoke.cjs
```

The script writes a screenshot to `/tmp/health-journal-mobile.png` by default. The
tracked `today-mobile.png` is a preview containing synthetic observations only.

Baseline: original commit 6fbf779 ran 261 tests and 19 properties, with 3 pre-existing
failures (confirmation flash, habit toggle payload, daily journal delete payload).
These were recorded before replacement, separately from the passing new tests.

Dependency review: compatible Phoenix 1.8, LiveView 1.1, Plug and Postgrex patches
were applied after Hex reported advisories in the original lock. Hex still reports
advisories for the constrained transitive Hackney 1.25 and Decimal 2.4 dependencies;
the journal does not accept arbitrary remote URLs or arbitrary-precision decimal
input. This is not a claim that all transitive advisories are resolved. Review
supported dependency fixes during ongoing maintenance. External error reporting,
mail delivery, behavioral analytics and admin access were removed. Structured OTP
crash reports are suppressed/redacted because they can inspect raw LiveView assigns;
this intentionally reduces diagnostic detail to keep journal data out of logs.

Per the owner's updated scope, ARM64 emulation/build checks and Oracle deployment
work were stopped and temporary emulation resources removed. No production image,
backup/restore rehearsal, production resource measurement or deployment is claimed.
An optional Dockerfile remains as unverified source; no server was accessed.

Pending on a real iPhone (Safari and installed home-screen app):

- Home-screen install/open and persistent session behavior.
- Actual camera capture, photo-library HEIC, background/lock/suspension and reconnect.
- Interrupted upload/reselection, photo preview/reveal/delete and export downloads.
- Keyboard, safe areas, text zoom and touch controls on physical hardware.

Desktop mobile Chromium is useful coverage, not proof of any of those device checks.
