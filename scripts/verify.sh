#!/usr/bin/env bash
#
# Repository verification entry point (run by the dev pipeline after every task, after every
# merge into the integration branch and at integration). Every component adds its checks here.
#
# Rules:
#   - non-interactive, deterministic, exits non-zero on any failure
#   - skip components that do not exist
#   - Windows Git Bash compatible
#
# Usage (from anywhere): bash scripts/verify.sh
# Env:   GODOT_EXE   Godot 4.7 console executable (default: D:\Godot\...\..._console.exe, then `godot`)
#        VERIFY_SKIP_WEB=1 / VERIFY_SKIP_GODOT=1 to skip a component locally

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

ran=0

# Godot test scripts that cannot run headless (need a real GPU renderer); run them by hand.
GODOT_SKIP_TESTS=" render_regression_test "
GODOT_TEST_TIMEOUT=300

# --- web (Three.js original, Vite) -------------------------------------------
if [ -f package.json ] && [ "${VERIFY_SKIP_WEB:-0}" != "1" ]; then
  echo "verify: web (vite build)"
  if [ ! -d node_modules ]; then
    npm ci --no-audit --no-fund
  fi
  node tools/mobile-web-quality-test.mjs
  npm run build
  ran=$((ran + 1))
fi

# --- godot port ----------------------------------------------------------------
find_godot() {
  local cands=(
    "${GODOT_EXE:-}"
    "/d/Godot/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe"
    "D:/Godot/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe"
  )
  local c
  for c in "${cands[@]}"; do
    if [ -n "$c" ] && [ -f "$c" ]; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  command -v godot 2>/dev/null || return 1
}

# Godot's importer rewrites tracked *.import files with LF endings (core.autocrlf), which git
# lists as modified although the content is identical. Revert those so they never show up as diffs.
drop_phantom_changes() {
  local real f
  real="$(git diff --name-only)"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if ! grep -qxF -- "$f" <<<"$real"; then
      git checkout -q -- "$f"
    fi
  done < <(git status --porcelain --untracked-files=no | awk '$1 == "M" { sub(/^ ?M +/, ""); print }')
}

# Run a Godot command, echo its output, and fail on a non-zero exit or any script error.
run_godot() {
  local label="$1"; shift
  local log status=0
  log="$(mktemp)"
  timeout "$GODOT_TEST_TIMEOUT" "$godot" --headless --path godot "$@" >"$log" 2>&1 || status=$?
  cat "$log"
  if [ "$status" -ne 0 ]; then
    rm -f "$log"
    echo "verify: godot $label failed (exit $status)" >&2
    return 1
  fi
  if grep -qE 'SCRIPT ERROR|Parse Error|Failed to load script' "$log"; then
    rm -f "$log"
    echo "verify: godot $label printed script errors" >&2
    return 1
  fi
  rm -f "$log"
}

if [ -f godot/project.godot ] && [ "${VERIFY_SKIP_GODOT:-0}" != "1" ]; then
  if ! godot="$(find_godot)"; then
    echo "verify: Godot executable not found; set GODOT_EXE" >&2
    exit 1
  fi
  echo "verify: godot import ($godot)"
  run_godot import --import
  drop_phantom_changes
  for test_path in godot/tools/*_test.gd; do
    [ -f "$test_path" ] || continue
    name="$(basename "$test_path" .gd)"
    if [[ "$GODOT_SKIP_TESTS" == *" $name "* ]]; then
      echo "verify: godot $name skipped (needs GPU)"
      continue
    fi
    echo "verify: godot $name"
    run_godot "$name" --script "res://tools/$name.gd"
  done
  drop_phantom_changes
  ran=$((ran + 1))
fi

if [ "$ran" -eq 0 ]; then
  echo "verify: no components (skipped)"
fi
echo "verify: ok"
