# Scripts

## release.sh

The only sanctioned way to cut a release. Do not edit the manifest or push
by hand; releases 0.9.1-5/-6 were cut by ad-hoc shell where a failed
validation step did not stop the push, shipping a manifest still labeled
0.9.1-4 (existing users got no update prompt).

```
scripts/release.sh <app-version> [--dashboard-image <ref>] [--wrapper-image <ref>] \
    [--notes-file <path>] [--allow-branch] [--push]
```

- `<app-version>` must match `X.Y.Z-N` (homeserver version + packaging
  suffix, see the repo README's "Versioning" section) and be strictly newer
  than the current manifest version.
- `--dashboard-image` / `--wrapper-image` update the corresponding `image:`
  line in `docker-compose.yml`. Refs without an `@sha256:` digest are
  resolved automatically (docker buildx imagetools, docker manifest
  inspect, skopeo); if resolution fails, pass `<ref>@sha256:<digest>`
  explicitly.
- `--notes-file` is a plain-text file (paragraphs separated by blank
  lines) prepended as the new top section of `releaseNotes`. A
  `Version <v>:` header is added if missing and the previous top section
  is rewritten to `Plus X:`.
- Validation (always runs): manifest version matches the argument, the
  first releaseNotes line mentions the new version, every compose image is
  digest-pinned, and both files parse (docker compose config and/or
  python3 YAML).
- By default the script commits locally and prints next steps; only
  `--push` pushes. Any failure aborts loudly and rolls the files back.

Example:

```
scripts/release.sh 0.9.1-7 \
    --dashboard-image synonymsoft/homeserver-dashboard:v0.1.13 \
    --notes-file /tmp/notes-0.9.1-7.txt
```
