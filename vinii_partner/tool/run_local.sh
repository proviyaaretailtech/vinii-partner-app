#!/usr/bin/env bash
# Runs VINII Partner with values from an env file passed as --dart-define flags.
#
#   ./tool/run_local.sh                       # .env.local, default device
#   ./tool/run_local.sh -d chrome             # any extra flutter run flags
#   VINII_ENV_FILE=.env.localdb ./tool/run_local.sh
#
# Only the keys below are accepted. Anything else — above all a Supabase
# service-role key — is refused, so a secret can never be compiled into the app.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${VINII_ENV_FILE:-$ROOT/.env.local}"
[[ "$ENV_FILE" = /* ]] || ENV_FILE="$ROOT/$ENV_FILE"

args=()
if [[ -f "$ENV_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" != *=* ]]; then
      printf 'Invalid env line (expected KEY=VALUE): %s\n' "$line" >&2
      exit 1
    fi
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      APP_ENV|SUPABASE_URL|SUPABASE_PUBLISHABLE_KEY|PARTNER_API_BASE_URL|STOREFRONT_BASE_URL)
        args+=("--dart-define=${key}=${value}") ;;
      *)
        printf 'Refusing unsupported or secret env key: %s\n' "$key" >&2
        exit 1 ;;
    esac
  done < "$ENV_FILE"
else
  printf 'Missing %s\nCopy .env.local.example to .env.local and fill in the Supabase URL and publishable key.\n' "$ENV_FILE" >&2
  exit 1
fi

cd "$ROOT"
exec flutter run ${args[@]+"${args[@]}"} "$@"
