import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = path.dirname(fileURLToPath(import.meta.url));

export default async function globalTeardown() {
  const runPath = path.join(rootDir, 'runtime', 'run.json');
  const summaryPath = path.join(rootDir, 'artifacts', 'run-summary.json');
  const run = fs.existsSync(runPath) ? JSON.parse(fs.readFileSync(runPath, 'utf8')) : {};
  fs.mkdirSync(path.dirname(summaryPath), { recursive: true });
  fs.writeFileSync(
    summaryPath,
    `${JSON.stringify(
      {
        ...run,
        finishedAt: new Date().toISOString(),
        note: 'Database restoration is intentionally handled by scripts/backup-reset-restore.sh and is never hidden by teardown.',
      },
      null,
      2,
    )}\n`,
  );
}
