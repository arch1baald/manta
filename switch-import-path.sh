#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./switch-import-path.sh arch1baald [--dry-run]
  ./switch-import-path.sh dotabuff [--dry-run]

What it does:
  - Rewrites import/module paths between:
      github.com/arch1baald/manta   <->   github.com/arch1baald/manta
  - Updates go.mod "module ..." line accordingly.
  - Applies to tracked text files (git ls-files), skipping binaries.

Notes:
  - Run from manta root (this script enforces it).
  - After switching, you may need to run: go mod tidy / go test ./...
EOF
}

MODE="${1:-}"
DRY_RUN=false
if [[ "${2:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

if [[ "$MODE" != "arch1baald" && "$MODE" != "dotabuff" ]]; then
  usage
  exit 2
fi

MANTA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$MANTA_ROOT"

if [[ ! -f "go.mod" ]]; then
  echo "Error: go.mod not found. Run this script from manta root." >&2
  exit 2
fi

DOTABUFF="github.com/dotabuff/manta"
ARCH="github.com/arch1baald/manta"

FROM=""
TO=""
MODULE_TO=""
if [[ "$MODE" == "arch1baald" ]]; then
  FROM="$DOTABUFF"
  TO="$ARCH"
  MODULE_TO="$ARCH"
else
  FROM="$ARCH"
  TO="$DOTABUFF"
  MODULE_TO="$DOTABUFF"
fi

echo "Mode: $MODE"
echo "From: $FROM"
echo "To:   $TO"
if $DRY_RUN; then
  echo "Dry-run: yes"
else
  echo "Dry-run: no"
fi
echo

changed_files=0

# Update module path in go.mod (even if imports already match).
if grep -qE '^module[[:space:]]+github\.com/(dotabuff|arch1baald)/manta[[:space:]]*$' go.mod; then
  if $DRY_RUN; then
    if ! grep -qE "^module[[:space:]]+$MODULE_TO[[:space:]]*$" go.mod; then
      echo "[DRY] would update go.mod module path -> $MODULE_TO"
      changed_files=$((changed_files + 1))
    fi
  else
    perl -pi -e "s#^module[ \t]+github\\.com/(dotabuff|arch1baald)/manta[ \t]*\$#module $MODULE_TO#" go.mod
  fi
fi

# Rewrite all tracked text files that contain FROM.
while IFS= read -r -d '' f; do
  # Never rewrite this script itself (otherwise it corrupts DOTABUFF/ARCH values).
  if [[ "$f" == "switch-import-path.sh" ]]; then
    continue
  fi

  # Skip obvious non-text/binary files.
  if ! grep -Iq . "$f" 2>/dev/null; then
    continue
  fi
  if ! grep -q "$FROM" "$f" 2>/dev/null; then
    continue
  fi

  if $DRY_RUN; then
    echo "[DRY] would rewrite: $f"
  else
    # Use '|' delimiter so we don't need to escape '/' inside module paths.
    perl -pi -e "s|\\Q$FROM\\E|$TO|g" "$f"
  fi
  changed_files=$((changed_files + 1))
done < <(git ls-files -z)

echo
echo "Done. Files touched: $changed_files"
if $DRY_RUN; then
  echo "Re-run without --dry-run to apply."
fi


