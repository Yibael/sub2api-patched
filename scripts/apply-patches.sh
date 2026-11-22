#!/usr/bin/env bash
# Apply every patches/*.patch to an official sub2api checkout.
#
#   scripts/apply-patches.sh <sub2api checkout>
#
# For each patch:
#   - applies cleanly            -> apply it
#   - already in the checkout    -> skip it (upstream merged it)
#   - neither                    -> fail: upstream changed that code and the patch needs updating
#
# Writes "applied=N" and "merged=<names>" to $GITHUB_OUTPUT when set.
set -euo pipefail

src=${1:?usage: apply-patches.sh <sub2api checkout>}
here=$(cd "$(dirname "$0")/.." && pwd)
applied=0
merged=()
failed=()

shopt -s nullglob
for patch in "$here"/patches/*.patch; do
  name=$(basename "$patch")
  if git -C "$src" apply --check "$patch" 2>/dev/null; then
    git -C "$src" apply "$patch"
    applied=$((applied + 1))
    echo "applied  $name"
  elif git -C "$src" apply --check --reverse "$patch" 2>/dev/null; then
    merged+=("$name")
    echo "upstream $name (already in this version, skipped)"
  else
    failed+=("$name")
    echo "CONFLICT $name"
  fi
done

if [[ -n ${GITHUB_OUTPUT:-} ]]; then
  echo "applied=$applied" >>"$GITHUB_OUTPUT"
  echo "merged=${merged[*]:-}" >>"$GITHUB_OUTPUT"
fi

if ((${#failed[@]} > 0)); then
  echo "::error::these patches no longer apply to this sub2api version and need updating: ${failed[*]}"
  exit 1
fi
