#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_CODEX_PYTHON="/Users/arthurnariz/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
if [[ -z "${PYTHON_BIN:-}" ]]; then
  if [[ -x "$DEFAULT_CODEX_PYTHON" ]]; then
    PYTHON_BIN="$DEFAULT_CODEX_PYTHON"
  else
    PYTHON_BIN="python3"
  fi
fi
DB_NAME="${DB_NAME:-db_brokerlab_reimport_test}"
PSQL_BIN="${PSQL_BIN:-psql}"
PSQL_USER="${PSQL_USER:-postgres}"

run_psql() {
  "$PSQL_BIN" -U "$PSQL_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -f "$1"
}

echo "==> Validando templates"
"$PYTHON_BIN" "$REPO_ROOT/scripts/load_config_domain_templates.py" --check-only

echo "==> Gerando SQL governado de config/domain"
"$PYTHON_BIN" "$REPO_ROOT/scripts/load_config_domain_templates.py" --dbname "$DB_NAME"

echo "==> Aplicando config/domain em $DB_NAME"
run_psql "$REPO_ROOT/artefatos/generated/config_domain_template_load.sql"

echo "==> Recriando schema gold"
run_psql "$REPO_ROOT/bd/gold/gold_ddl.sql"
run_psql "$REPO_ROOT/bd/gold/gold_load_dimensions.sql"
run_psql "$REPO_ROOT/bd/gold/gold_load_facts.sql"
run_psql "$REPO_ROOT/bd/gold/gold_views.sql"

echo "==> Rodando checks do gold"
run_psql "$REPO_ROOT/bd/gold/gold_checks.sql"

echo "==> Concluido"
