#!/usr/bin/env bash
set -euo pipefail

# Operator-only utility. Never put SUPABASE_SERVICE_ROLE_KEY in the app, repo, CI logs, or chat.
PROJECT_URL="${SUPABASE_URL:-https://gjodhvpzkdnxdjmorjfw.supabase.co}"
BUCKET="${SUPABASE_BUILD_ASSETS_BUCKET:-toti-build-assets}"
SOURCE_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)/Assets}"

: "${SUPABASE_SERVICE_ROLE_KEY:?Set SUPABASE_SERVICE_ROLE_KEY in the operator environment}"
[[ -d "$SOURCE_DIR" ]] || { echo "Source directory does not exist: $SOURCE_DIR" >&2; exit 1; }

find "$SOURCE_DIR" -type f -print0 | sort -z | while IFS= read -r -d '' file; do
  name="${file#"$SOURCE_DIR"/}"
  content_type="$(file -b --mime-type "$file")"
  curl --fail-with-body --silent --show-error --retry 3 --retry-delay 2 \
    -X POST "$PROJECT_URL/storage/v1/object/$BUCKET/$name" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "x-upsert: true" -H "Content-Type: $content_type" \
    --data-binary "@$file" >/dev/null
  printf 'uploaded %s\n' "$name"
done

echo "Upload complete. Verify every manifest URL before switching the app from the current origin."
