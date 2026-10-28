# CRMEB H5 and Admin E2E

This suite validates the local H5 storefront, admin UI, both APIs, and selected
database invariants. It uses the installed Google Chrome channel and never
stores real credentials or tokens in source control.

## Prerequisites

- Node.js 18 or newer
- Google Chrome
- MySQL and Redis matching the application configuration
- Both Java services running on JDK 8
- H5 on `5273`, admin UI on `9527`, front API on `8081`, admin API on `8080`

Create a local `.env` from `.env.example` and supply two isolated storefront
users plus one local administrator. Runtime auth state is written under
`auth/` and ignored by Git.

## Run

```bash
cd tests/e2e
npm ci
npx playwright test --project=h5-mobile --grep @smoke
npx playwright test --project=admin-desktop --grep @smoke
npm run test:full
```

Tests use `retries=0`. A failed blocker must be diagnosed from its screenshot,
trace, console/network evidence, service logs, and database checks. Do not
rerun until green without explaining the first failure.

## Data Safety

Database reset and restore require explicit opt-in:

```bash
cd tests/e2e
MYSQL_PASSWORD=... ./scripts/backup-reset-restore.sh backup
ALLOW_DB_RESET=1 MYSQL_PASSWORD=... ./scripts/backup-reset-restore.sh reset-twice
MYSQL_PASSWORD=... ./scripts/backup-reset-restore.sh verify
ALLOW_DB_RESET=1 MYSQL_PASSWORD=... \
  E2E_DB_BACKUP=/tmp/crmeb-e2e-before-YYYYMMDD-HHMMSS.sql \
  ./scripts/backup-reset-restore.sh restore
```

The suite does not restore the database automatically. This is intentional:
teardown must never hide a failed or partial restore.

## Evidence

- `artifacts/results.json`: machine-readable Playwright result
- `artifacts/html-report/`: HTML report
- `artifacts/test-results/`: screenshots and traces for failures
- `artifacts/run-summary.json`: run metadata
- `runtime/fixtures.json`: run-specific IDs and temporary tokens, Git-ignored

External payment, SMS, logistics, printing, and cloud services are not called.
Only local development simulators and unconfigured/error boundaries are tested.
