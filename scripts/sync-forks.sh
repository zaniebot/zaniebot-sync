#!/usr/bin/env bash
set -euo pipefail

TARGETS_FILE="${1:-targets.txt}"

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

is_ci() {
  [[ "${CI:-}" == "true" ]]
}

group_start() {
  local label="$1"

  if is_ci; then
    echo "::group::$label"
  else
    echo "$label"
  fi
}

group_end() {
  if is_ci; then
    echo "::endgroup::"
  fi
}

if [[ ! -f "$TARGETS_FILE" ]]; then
  echo "Targets file not found: $TARGETS_FILE" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "GH_TOKEN is not set. Configure the FORK_SYNC_TOKEN secret." >&2
  exit 1
fi

overall_status=0
repo_error_file="$(mktemp)"
sync_error_file="$(mktemp)"
trap 'rm -f "$repo_error_file" "$sync_error_file"' EXIT

while IFS= read -r line || [[ -n "$line" ]]; do
  line="$(trim "$line")"

  if [[ -z "$line" || "$line" == \#* ]]; then
    continue
  fi

  target="$line"

  if [[ ! "$target" =~ ^[^/]+/[^/]+$ ]]; then
    echo "Invalid target format: $target" >&2
    overall_status=1
    continue
  fi

  group_start "Syncing $target"

  if ! repo_json="$(gh api "repos/$target" 2>"$repo_error_file")"; then
    echo "Failed to read repository metadata for $target" >&2
    cat "$repo_error_file" >&2
    overall_status=1
    group_end
    continue
  fi

  is_fork="$(jq -r '.fork' <<<"$repo_json")"
  default_branch="$(jq -r '.default_branch' <<<"$repo_json")"
  parent_full_name="$(jq -r '.parent.full_name // empty' <<<"$repo_json")"

  if [[ "$is_fork" != "true" ]]; then
    echo "$target is not marked as a fork" >&2
    overall_status=1
    group_end
    continue
  fi

  if [[ -z "$parent_full_name" ]]; then
    echo "$target does not report an upstream parent" >&2
    overall_status=1
    group_end
    continue
  fi

  echo "Upstream: $parent_full_name"
  echo "Branch: $default_branch"

  if response="$(gh api \
    --method POST \
    -H "Accept: application/vnd.github+json" \
    "repos/$target/merge-upstream" \
    -f branch="$default_branch" 2>"$sync_error_file")"; then
    message="$(jq -r '.message // "Sync completed"' <<<"$response")"
    echo "$message"
  else
    echo "Failed to sync $target" >&2
    cat "$sync_error_file" >&2
    overall_status=1
  fi

  group_end
done < "$TARGETS_FILE"

exit "$overall_status"
