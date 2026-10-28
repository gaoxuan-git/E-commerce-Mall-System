import { spawnSync } from 'node:child_process';

function mysqlArgs() {
  return [
    `--host=${process.env.MYSQL_HOST || '127.0.0.1'}`,
    `--port=${process.env.MYSQL_PORT || '3306'}`,
    `--user=${process.env.MYSQL_USER || 'root'}`,
    '--batch',
    '--raw',
    '--skip-column-names',
    process.env.MYSQL_DATABASE || 'dexter_dianshang',
  ];
}

export function queryRows(sql) {
  if (!/^\s*(SELECT|SHOW|DESCRIBE|EXPLAIN|WITH)\b/i.test(sql)) {
    throw new Error('E2E database helper only permits read-only SQL');
  }
  const result = spawnSync('mysql', [...mysqlArgs(), '--execute', sql], {
    encoding: 'utf8',
    env: {
      ...process.env,
      MYSQL_PWD: process.env.MYSQL_PASSWORD || '',
    },
  });
  if (result.status !== 0) {
    throw new Error(`MySQL query failed: ${result.stderr.trim()}`);
  }
  const output = result.stdout.trim();
  return output ? output.split('\n').map((line) => line.split('\t')) : [];
}

export function queryScalar(sql) {
  return queryRows(sql)[0]?.[0];
}
