#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DB_HOST="${MYSQL_HOST:-127.0.0.1}"
DB_PORT="${MYSQL_PORT:-3306}"
DB_USER="${MYSQL_USER:-root}"
DB_NAME="${MYSQL_DATABASE:-dexter_dianshang}"
REDIS_DB="${REDIS_DB:-10}"
BACKUP_FILE="${E2E_DB_BACKUP:-/tmp/crmeb-e2e-before-$(date +%Y%m%d-%H%M%S).sql}"

export MYSQL_PWD="${MYSQL_PASSWORD:-}"

mysql_cmd() {
  mysql --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" "$DB_NAME" "$@"
}

require_reset_permission() {
  if [[ "${ALLOW_DB_RESET:-0}" != "1" ]]; then
    printf 'Refusing destructive database operation. Set ALLOW_DB_RESET=1 explicitly.\n' >&2
    exit 2
  fi
}

case "$MODE" in
  backup)
    mysqldump \
      --host="$DB_HOST" \
      --port="$DB_PORT" \
      --user="$DB_USER" \
      --single-transaction \
      --routines \
      --triggers \
      --events \
      --set-gtid-purged=OFF \
      "$DB_NAME" > "$BACKUP_FILE"
    test -s "$BACKUP_FILE"
    grep -q 'Table structure for table `eb_store_product`' "$BACKUP_FILE"
    grep -q 'Table structure for table `eb_store_order`' "$BACKUP_FILE"
    grep -q 'Table structure for table `eb_system_config`' "$BACKUP_FILE"
    shasum -a 256 "$BACKUP_FILE"
    printf '%s\n' "$BACKUP_FILE"
    ;;
  reset)
    require_reset_permission
    mysql_cmd < "$ROOT_DIR/backend/sql/local-demo-data.sql"
    redis-cli -n "$REDIS_DB" FLUSHDB
    ;;
  reset-twice)
    require_reset_permission
    mysql_cmd < "$ROOT_DIR/backend/sql/local-demo-data.sql"
    mysql_cmd < "$ROOT_DIR/backend/sql/local-demo-data.sql"
    redis-cli -n "$REDIS_DB" FLUSHDB
    ;;
  verify)
    mysql_cmd < "$ROOT_DIR/tests/e2e/sql/assert-demo-integrity.sql"
    ;;
  restore)
    require_reset_permission
    if [[ ! -s "$BACKUP_FILE" ]]; then
      printf 'Backup file is missing or empty: %s\n' "$BACKUP_FILE" >&2
      exit 3
    fi
    mysql_cmd < "$BACKUP_FILE"
    redis-cli -n "$REDIS_DB" FLUSHDB
    ;;
  *)
    printf 'Usage: %s {backup|reset|reset-twice|verify|restore}\n' "$0" >&2
    exit 64
    ;;
esac
