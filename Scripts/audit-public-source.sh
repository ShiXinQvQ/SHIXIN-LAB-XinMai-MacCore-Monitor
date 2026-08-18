#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'Public-source audit failed: %s\n' "$1" >&2
  exit 1
}

TRACKED_IGNORED="$(git ls-files -ci --exclude-standard)"
if [ -n "$TRACKED_IGNORED" ]; then
  printf '%s\n' "$TRACKED_IGNORED" >&2
  fail "tracked files still match local-only ignore rules"
fi

for forbidden_path in \
  AI_CONTEXT \
  LOGO图 \
  芯脉软件截屏 \
  docs/handoffs \
  output \
  tmp \
  Dist; do
  if git ls-files -- "$forbidden_path" | grep -q .; then
    fail "local-only path is tracked: $forbidden_path"
  fi
done

if git grep -I -n -E '/Users/[A-Za-z0-9._-]+/|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AIza[0-9A-Za-z_-]{30,}|sk-[A-Za-z0-9]{20,}' \
  -- . ':(exclude)Scripts/audit-public-source.sh' >/dev/null; then
  git grep -I -n -E '/Users/[A-Za-z0-9._-]+/|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AIza[0-9A-Za-z_-]{30,}|sk-[A-Za-z0-9]{20,}' \
    -- . ':(exclude)Scripts/audit-public-source.sh' >&2
  fail "tracked source contains a machine path or credential-shaped value"
fi

if git grep -I -n -E '^(<<<<<<<|=======|>>>>>>>)' -- . >/dev/null; then
  fail "merge-conflict markers remain in tracked text"
fi

oversized=0
while IFS= read -r -d '' path; do
  size="$(stat -f '%z' "$path")"
  if [ "$size" -gt 10000000 ]; then
    printf '%s bytes  %s\n' "$size" "$path" >&2
    oversized=1
  fi
done < <(git ls-files -z)

if [ "$oversized" -ne 0 ]; then
  fail "tracked working-tree files larger than 10 MB remain"
fi

git diff --check
git diff --cached --check

printf '%s\n' 'Public-source working-tree audit passed.'
