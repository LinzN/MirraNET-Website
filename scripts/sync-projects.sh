#!/usr/bin/env bash
# Pulls what the website shows about the MirraNET projects into the site
# folder: the project icons and, for every repository, its latest release
# and last activity.
#
# Usage: scripts/sync-projects.sh <checkouts-dir> [site-dir]
#
# <checkouts-dir> holds (sparse) checkouts named freex/, ondura/ and parla/
# (FreeX-Studio/Freex-Media-Server, Ondura-Suite/Ondura-Core and
# Parla-Studio/parla). A missing checkout or icon is reported and replaced
# by the MirraNET mark, so one renamed file never breaks the whole site.
# GITHUB_TOKEN is optional; without it the GitHub API rate limit for
# anonymous requests applies (fine for local use).

set -euo pipefail

SRC_DIR="${1:?directory with the project checkouts required}"
SITE_DIR="${2:-$(dirname "$0")/../site}"
brand="$SITE_DIR/assets/brand"
mkdir -p "$brand"

# Icons: each project's own repository is the single source of truth.
declare -A ICONS=(
  [freex]="freex/docs/brand/freex-app-icon.svg"
  [ondura]="ondura/apps/ondura/public/ondura.svg"
  [parla]="parla/docs/logo.svg"
)
for key in "${!ICONS[@]}"; do
  src="$SRC_DIR/${ICONS[$key]}"
  if [[ -f "$src" ]]; then
    cp "$src" "$brand/$key.svg"
  else
    echo "warning: $src not found, using the MirraNET mark for $key" >&2
    cp "$brand/mirranet-mark.svg" "$brand/$key.svg"
  fi
done

# Repository facts, reduced to the fields the page needs. Written as
# projects.json so visitors never talk to the GitHub API themselves.
auth=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi
api() {
  curl -fsSL "${auth[@]}" -H "Accept: application/vnd.github+json" "https://api.github.com/$1"
}

declare -A REPOS=(
  [stem]=LinzN/Stem
  [mirra]=LinzN/mirra
  [freex]=FreeX-Studio/Freex-Media-Server
  [ondura]=Ondura-Suite/Ondura-Core
  [parla]=Parla-Studio/parla
  [parla-server]=Parla-Studio/parla-server
  [midea-ac]=LinzN/midea-ac
  [midea2mqtt]=LinzN/midea2mqtt
  [snapmaker2mqtt]=LinzN/snapmaker2mqtt
  [wiim-java-api]=LinzN/wiim-java-api
  [SimplyConfiguration]=LinzN/SimplyConfiguration
  [SimplyLogger]=LinzN/SimplyLogger
  [OpenJL]=LinzN/OpenJL
)

out="{}"
for key in "${!REPOS[@]}"; do
  repo="${REPOS[$key]}"
  meta="$(api "repos/$repo" || echo 'null')"
  releases="$(api "repos/$repo/releases?per_page=20" || echo '[]')"
  entry="$(jq -n --arg repo "$repo" --argjson meta "$meta" --argjson releases "$releases" '
    ((if ($releases | type) == "array" then $releases else [] end) | map(select(.draft | not)) | first) as $r |
    {
      repo: $repo,
      url: ($meta.html_url // "https://github.com/\($repo)"),
      language: ($meta.language // null),
      pushed_at: ($meta.pushed_at // null),
      release: (if $r == null then null else {
        tag: $r.tag_name,
        published_at: $r.published_at,
        html_url: $r.html_url
      } end)
    }')"
  out="$(jq --arg k "$key" --argjson v "$entry" '. + {($k): $v}' <<<"$out")"
  echo "$repo: $(jq -r '.release.tag // "no release"' <<<"$entry")"
done
# Number of public repositories of the LinzN account, for "see all N repositories".
account="$(api "users/LinzN" || echo 'null')"
out="$(jq --argjson a "$account" '. + {_account: {public_repos: ($a.public_repos // null)}}' <<<"$out")"

jq -S . <<<"$out" > "$SITE_DIR/projects.json"

echo "Synced ${#ICONS[@]} icons and ${#REPOS[@]} repositories into projects.json."
