#!/usr/bin/env bash

# Copyright (C) 2026 SHIXIN LAB / Shixin
# SPDX-License-Identifier: GPL-3.0-or-later
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

if git grep -I -n -E 'shixinqvq\.com/lab/xinmai/|Advanced Access|performs no disk writes|不写盘|Source-Available' \
  -- README.md Packaging/PublicBetaDocs Scripts/release-public-beta.sh >/dev/null; then
  git grep -I -n -E 'shixinqvq\.com/lab/xinmai/|Advanced Access|performs no disk writes|不写盘|Source-Available' \
    -- README.md Packaging/PublicBetaDocs Scripts/release-public-beta.sh >&2
  fail "obsolete public-release wording remains"
fi

while IFS= read -r -d '' path; do
  if ! grep -Fq 'SPDX-License-Identifier: GPL-3.0-or-later' "$path"; then
    fail "source file is missing its GPL SPDX notice: $path"
  fi
done < <(
  find Sources -type f \
    \( -name '*.swift' -o -name '*.m' -o -name '*.h' \) -print0
)

for path in Package.swift Scripts/*.sh Scripts/*.py Scripts/*.swift; do
  if ! grep -Fq 'SPDX-License-Identifier: GPL-3.0-or-later' "$path"; then
    fail "build or validation source is missing its GPL SPDX notice: $path"
  fi
done

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
