#!/usr/bin/env bash
# rewrite_identifiers.sh — rewrite the bundled-demo placeholder identifiers
# (@nx-mixed, NxMixed, nx-mixed) to whatever this workspace is actually called.
#
# Usage:
#   rewrite_identifiers.sh <workspace-root> <npm-scope> <PascalCaseName> <workspace-name>
#
# Example (workspace called "acme-platform" with scope "@acme"):
#   rewrite_identifiers.sh . acme AcmePlatform acme-platform
#
# What it does (in this exact order — order matters):
#   1. "&#64;nx-mixed" -> "&#64;<scope>" HTML-encoded scope (e.g. shared-ui.html
#                                         where the at-sign is escaped because
#                                         "@" collides with Angular's @if / @for
#                                         control-flow syntax)
#   2. "@nx-mixed"     -> "@<scope>"     TS imports, tsconfig path aliases
#   3. "NxMixed"       -> "<PascalName>" .sln name, C# namespaces (none in
#                                         the bundled demo today, but kept for
#                                         forward-compat when you add libs)
#   4. "nx-mixed"      -> "<name>"       package.json "name", READMEs, misc
#
# The order matters: "@nx-mixed" and "&#64;nx-mixed" both contain the bare
# token "nx-mixed". If we rewrote that first we'd strand a lonely "@" prefix
# pointing at the workspace name instead of the scope.
#
# Safety:
#   - Skips any path under node_modules, .git, dist, .nx, .angular, bin, obj.
#   - Operates only on text files (binary detection via `grep -Iq`).
#   - Edits in place with sed -i. Targets bash + GNU sed (the bundled
#     devcontainer ships both). On macOS sed swap `sed -i` for `sed -i ''`.

set -euo pipefail

if [ $# -ne 4 ]; then
  echo "usage: $0 <workspace-root> <npm-scope> <PascalCaseName> <workspace-name>" >&2
  exit 2
fi

ROOT=$1
SCOPE=$2
PASCAL=$3
NAME=$4

if [ ! -d "$ROOT" ]; then
  echo "error: workspace root '$ROOT' is not a directory" >&2
  exit 1
fi

# Normalize the scope: accept "@acme" or "acme", emit "acme" for use in the
# replacement string (we re-add the "@" in the sed pattern).
SCOPE=${SCOPE#@}

echo "rewriting identifiers under $ROOT:"
echo "  @nx-mixed -> @$SCOPE"
echo "  NxMixed   -> $PASCAL"
echo "  nx-mixed  -> $NAME"

# Find candidate files. -print0 / xargs -0 keeps spaces-in-filenames safe.
# The path filters mirror this repo's .gitignore plus a few generated dirs.
find "$ROOT" \
  -type d \( \
       -name node_modules \
    -o -name .git \
    -o -name .nx \
    -o -name .angular \
    -o -name dist \
    -o -name out-tsc \
    -o -name coverage \
    -o -name bin \
    -o -name obj \
    -o -name __screenshots__ \
  \) -prune -o \
  -type f -print0 \
| while IFS= read -r -d '' f; do
    # Skip binary files. `grep -Iq` returns non-zero on binary input.
    if ! grep -Iq . "$f" 2>/dev/null; then
      continue
    fi
    # Cheap pre-check so we don't sed every text file in the repo.
    if grep -Eq '@nx-mixed|&#64;nx-mixed|NxMixed|nx-mixed' "$f"; then
      sed -i \
        -e "s|&#64;nx-mixed|\&#64;$SCOPE|g" \
        -e "s|@nx-mixed|@$SCOPE|g" \
        -e "s|NxMixed|$PASCAL|g" \
        -e "s|nx-mixed|$NAME|g" \
        "$f"
      echo "  patched: $f"
    fi
  done

echo "done."
