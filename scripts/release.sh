#!/usr/bin/env bash
#
# release.sh - the only sanctioned way to cut a release of the Pubky
# Homeserver Umbrel app. Born out of the 0.9.1-5/-6 incident, where an
# ad-hoc shell pipeline without `set -e` pushed a manifest still labeled
# 0.9.1-4 after a validation step had already failed, so existing users
# never saw an update prompt.
#
# Usage:
#   scripts/release.sh <app-version> [options]
#
#   <app-version>              New app version, MUST match X.Y.Z-N
#                              (homeserver version + packaging suffix,
#                              see README.md "Versioning") and be strictly
#                              newer than the current manifest version.
#
# Options:
#   --dashboard-image <ref>    New dashboard image for the `web` service.
#                              If <ref> has no @sha256: digest, the digest
#                              is resolved (docker buildx imagetools /
#                              docker manifest inspect / skopeo) and the
#                              pinned ref written to docker-compose.yml.
#   --wrapper-image <ref>      Same, for `homeserver-config-wrapper`.
#   --notes-file <path>        Plain-text release notes (paragraphs
#                              separated by blank lines). Prepended as the
#                              new top section of releaseNotes in
#                              umbrel-app.yml. A "Version <v>:" header is
#                              added if the first line does not already
#                              mention <v>, and the previous top section's
#                              "Version X:" header is rewritten to
#                              "Plus X:" per the established convention.
#   --allow-branch             Skip the "must be on master" check.
#   --push                     git push after committing. Default is to
#                              commit locally and print next steps.
#
# Every step fails loudly (set -euo pipefail + abort trap). On any failure
# before the commit, modified files are rolled back so the tree is left
# clean. Nothing is ever pushed unless --push is given AND every
# validation passed.

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO_ROOT/pubky-homeserver/umbrel-app.yml"
COMPOSE="$REPO_ROOT/pubky-homeserver/docker-compose.yml"

MUTATED=0
COMMITTED=0

on_exit() {
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    if [ "$MUTATED" -eq 1 ] && [ "$COMMITTED" -eq 0 ]; then
      git -C "$REPO_ROOT" checkout -q HEAD -- \
        pubky-homeserver/umbrel-app.yml pubky-homeserver/docker-compose.yml \
        2>/dev/null || true
      echo "(modified files rolled back to HEAD)" >&2
    fi
    printf '\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n' >&2
    printf '!!  RELEASE ABORTED (exit %-3s) - NOTHING WAS PUSHED  !!\n' "$rc" >&2
    printf '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n' >&2
  fi
}
trap on_exit EXIT

die() { echo "ERROR: $*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

usage() {
  sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 1
}

# ---------------------------------------------------------------- arguments

[ $# -ge 1 ] || usage
NEW_VERSION="$1"; shift

DASHBOARD_IMAGE=""
WRAPPER_IMAGE=""
NOTES_FILE=""
ALLOW_BRANCH=0
DO_PUSH=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dashboard-image) [ $# -ge 2 ] || die "--dashboard-image needs a value"; DASHBOARD_IMAGE="$2"; shift 2 ;;
    --wrapper-image)   [ $# -ge 2 ] || die "--wrapper-image needs a value";   WRAPPER_IMAGE="$2";   shift 2 ;;
    --notes-file)      [ $# -ge 2 ] || die "--notes-file needs a value";      NOTES_FILE="$2";      shift 2 ;;
    --allow-branch)    ALLOW_BRANCH=1; shift ;;
    --push)            DO_PUSH=1; shift ;;
    -h|--help)         usage ;;
    *)                 die "unknown argument: $1" ;;
  esac
done

[ -f "$MANIFEST" ] || die "manifest not found: $MANIFEST"
[ -f "$COMPOSE" ]  || die "compose file not found: $COMPOSE"
if [ -n "$NOTES_FILE" ]; then
  [ -f "$NOTES_FILE" ] || die "notes file not found: $NOTES_FILE"
fi

# ------------------------------------------------- step 1: git preconditions

step "Checking git tree and branch"

dirty="$(git -C "$REPO_ROOT" status --porcelain)"
[ -z "$dirty" ] || die "working tree is not clean; commit or stash first:
$dirty"

branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
if [ "$ALLOW_BRANCH" -eq 0 ] && [ "$branch" != "master" ]; then
  die "current branch is '$branch', not master (use --allow-branch to override)"
fi
echo "clean tree, branch: $branch"

# ------------------------------------------------ step 2: version sanity

step "Checking version $NEW_VERSION"

[[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$ ]] \
  || die "version '$NEW_VERSION' does not match X.Y.Z-N (never publish a bare version, see README.md)"

CUR_VERSION="$(sed -nE 's/^version:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/p' "$MANIFEST" | head -1)"
[ -n "$CUR_VERSION" ] || die "could not read current version from $MANIFEST"

# Strictly-newer comparison over the 4 numeric fields (X.Y.Z-N).
# A current version without -N (historic releases) is treated as -0.
is_newer() {
  local -a a b
  read -ra a <<<"$(echo "$1-0" | tr '.-' '  ')"
  read -ra b <<<"$(echo "$2-0" | tr '.-' '  ')"
  local i
  for i in 0 1 2 3; do
    if (( a[i] > b[i] )); then return 0; fi
    if (( a[i] < b[i] )); then return 1; fi
  done
  return 1 # equal is not newer
}
is_newer "$NEW_VERSION" "$CUR_VERSION" \
  || die "version $NEW_VERSION is not strictly newer than current manifest version $CUR_VERSION"
echo "ok: $CUR_VERSION -> $NEW_VERSION"

# -------------------------------------------- step 3: image refs (optional)

# Resolve the digest of an image ref (the multi-arch index digest, which is
# what we pin). Tries docker buildx imagetools, then docker manifest
# inspect, then skopeo.
resolve_digest() {
  local ref="$1" digest=""
  if command -v docker >/dev/null 2>&1; then
    # Parse the human-readable 'Digest:' line (the index digest); some
    # buildx versions silently ignore --format, so don't trust it.
    digest="$(docker buildx imagetools inspect "$ref" 2>/dev/null \
      | sed -nE 's/^Digest:[[:space:]]+(sha256:[0-9a-f]{64}).*/\1/p' | head -1 || true)"
    if [ -z "$digest" ]; then
      # docker manifest inspect -v only exposes a usable top-level digest
      # for single-platform images (a dict with a Descriptor); for
      # multi-arch indexes it returns a per-platform array, so skip those.
      digest="$(docker manifest inspect -v "$ref" 2>/dev/null \
        | python3 -c 'import json,sys
d = json.load(sys.stdin)
print(d["Descriptor"]["digest"] if isinstance(d, dict) and "Descriptor" in d else "")' \
        2>/dev/null || true)"
    fi
  fi
  if [ -z "$digest" ] && command -v skopeo >/dev/null 2>&1; then
    digest="$(skopeo inspect --format '{{.Digest}}' "docker://$ref" 2>/dev/null || true)"
  fi
  if [ -n "$digest" ] && ! [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    die "resolved digest for '$ref' looks malformed: '$digest'"
  fi
  [ -n "$digest" ] || die "could not resolve a digest for '$ref'
  (tried docker buildx imagetools / docker manifest inspect / skopeo).
  Resolve it yourself and pass the ref pinned explicitly:
      <ref>@sha256:<digest>
  e.g. docker buildx imagetools inspect $ref   # prints 'Digest: sha256:...'"
  echo "$digest"
}

# update_image <repo-prefix> <ref>: pin <ref> if needed and rewrite the
# single image: line in docker-compose.yml that starts with <repo-prefix>.
update_image() {
  local repo="$1" ref="$2"
  if [[ "$ref" != *@sha256:* ]]; then
    echo "resolving digest for $ref ..."
    local digest
    digest="$(resolve_digest "$ref")"
    ref="$ref@$digest"
  fi
  [[ "$ref" =~ ^[A-Za-z0-9._/-]+:[A-Za-z0-9._-]+@sha256:[0-9a-f]{64}$ ]] \
    || die "image ref '$ref' is not of the form repo:tag@sha256:<64-hex>"
  [[ "$ref" == "$repo":* ]] \
    || die "image ref '$ref' does not start with expected repo '$repo'"
  local count
  count="$(grep -cE "^[[:space:]]+image:[[:space:]]*$repo:" "$COMPOSE" || true)"
  [ "$count" = "1" ] || die "expected exactly 1 image: line for $repo in docker-compose.yml, found $count"
  MUTATED=1
  sed -i -E "s|^([[:space:]]+image:[[:space:]]*)$repo:[^[:space:]]+|\1$ref|" "$COMPOSE"
  grep -qF "image: $ref" "$COMPOSE" || die "failed to write new image ref for $repo"
  echo "pinned: $ref"
}

if [ -n "$DASHBOARD_IMAGE" ]; then
  step "Updating dashboard image"
  update_image "synonymsoft/homeserver-dashboard" "$DASHBOARD_IMAGE"
fi
if [ -n "$WRAPPER_IMAGE" ]; then
  step "Updating wrapper image"
  update_image "synonymsoft/homeserver-umbrel-config-wrapper" "$WRAPPER_IMAGE"
fi

# ------------------------------------------- step 4: release notes (optional)

if [ -n "$NOTES_FILE" ]; then
  step "Prepending release notes from $NOTES_FILE"
  MUTATED=1
  # Raw text surgery (python3 stdlib only) so the rest of the manifest
  # round-trips byte-for-byte. releaseNotes is a YAML folded block (>-):
  # body lines are indented 2 spaces and paragraphs are separated by TWO
  # blank lines (folded scalars need two empty lines to render "\n\n").
  python3 - "$MANIFEST" "$NOTES_FILE" "$NEW_VERSION" <<'PY'
import re, sys

manifest, notes_path, version = sys.argv[1], sys.argv[2], sys.argv[3]
raw = open(manifest).read()
notes = open(notes_path).read().strip()
if not notes:
    sys.exit("notes file is empty")

key = "releaseNotes: >-\n"
if raw.count(key) != 1:
    sys.exit("umbrel-app.yml no longer contains exactly one 'releaseNotes: >-' "
             "folded block; update scripts/release.sh before releasing")

paras = [p.strip() for p in re.split(r"\n[ \t]*\n", notes) if p.strip()]
if version not in paras[0].splitlines()[0]:
    paras.insert(0, "Version %s:" % version)

lines = []
for i, p in enumerate(paras):
    if i:
        lines += ["", ""]
    for line in p.splitlines():
        lines.append("  " + line.strip())
block = "\n".join(lines)

at = raw.index(key) + len(key)
head, tail = raw[:at], raw[at:]
# Previous top section becomes "Plus X:" per the file's convention.
tail = re.sub(r"^  Version (\S+:)", r"  Plus \1", tail, count=1, flags=re.M)
open(manifest, "w").write(head + block + "\n\n\n" + tail)
PY
  echo "notes prepended"
fi

# ----------------------------------------------- step 5: set manifest version

step "Setting version: \"$NEW_VERSION\" in umbrel-app.yml"
MUTATED=1
grep -qE '^version: ' "$MANIFEST" || die "no version: line in $MANIFEST"
sed -i -E "s|^version:.*|version: \"$NEW_VERSION\"|" "$MANIFEST"

# --------------------------------------------------------- step 6: validation

step "Validating"

# 6a. Manifest version equals the argument.
got="$(sed -nE 's/^version:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/p' "$MANIFEST" | head -1)"
[ "$got" = "$NEW_VERSION" ] \
  || die "manifest version is '$got', expected '$NEW_VERSION'"
echo "ok: manifest version is $NEW_VERSION"

# 6b. The first non-empty line of releaseNotes mentions the new version.
# This is exactly the 0.9.1-5/-6 incident class: version bumped, notes
# (or the whole manifest) stale.
first_note_line="$(awk '/^releaseNotes: >-/{f=1; next} f && NF {sub(/^[ \t]+/,""); print; exit}' "$MANIFEST")"
case "$first_note_line" in
  *"$NEW_VERSION"*) echo "ok: releaseNotes lead with: $first_note_line" ;;
  *) die "first releaseNotes line does not mention $NEW_VERSION: '$first_note_line'
  (pass --notes-file with notes for this release)" ;;
esac

# 6c. Every image in docker-compose.yml is digest-pinned.
unpinned="$(grep -E '^[[:space:]]+image:' "$COMPOSE" | grep -v '@sha256:' || true)"
[ -z "$unpinned" ] || die "image(s) in docker-compose.yml not pinned by @sha256: digest:
$unpinned"
echo "ok: all $(grep -cE '^[[:space:]]+image:' "$COMPOSE") images digest-pinned"

# 6d. Files parse. docker compose config needs a stub image for app_proxy
# (Umbrel injects the real one at install time, so the raw file is
# intentionally incomplete); fall back to a python3 YAML parse.
parsed=0
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  ov="$(mktemp)"
  printf 'services:\n  app_proxy:\n    image: busybox\n' > "$ov"
  if APP_PASSWORD=release-check APP_DATA_DIR=/tmp \
      docker compose -f "$COMPOSE" -f "$ov" config -q; then
    rm -f "$ov"
    echo "ok: docker compose config"
    parsed=1
  else
    rm -f "$ov"
    die "docker compose config rejected $COMPOSE"
  fi
fi
if python3 -c 'import yaml' 2>/dev/null; then
  python3 -c 'import sys, yaml
for f in sys.argv[1:]:
    yaml.safe_load(open(f))' "$MANIFEST" "$COMPOSE" \
    || die "python3 YAML parse failed"
  echo "ok: python3 YAML parse of manifest + compose"
  parsed=1
fi
[ "$parsed" -eq 1 ] || die "neither docker compose nor python3+yaml available to validate files"

# ------------------------------------------------------------ step 7: commit

step "Committing"
git -C "$REPO_ROOT" add pubky-homeserver/umbrel-app.yml pubky-homeserver/docker-compose.yml
git -C "$REPO_ROOT" commit -m "Release $NEW_VERSION"
COMMITTED=1

# -------------------------------------------------------- step 8: push (opt)

if [ "$DO_PUSH" -eq 1 ]; then
  step "Pushing"
  git -C "$REPO_ROOT" push
  echo
  echo "Release $NEW_VERSION pushed."
else
  echo
  echo "Release $NEW_VERSION committed locally (not pushed)."
  echo "Next steps:"
  echo "  - review:  git -C $REPO_ROOT show"
  echo "  - publish: git -C $REPO_ROOT push"
fi
