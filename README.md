# Pubky Umbrel App Store

A community [Umbrel](https://umbrel.com) app store that hosts the **Pubky Homeserver** for self-hosted Pubky users while the app is in beta.

Once the app graduates from beta, it will also be available directly from the official [Umbrel App Store](https://github.com/getumbrel/umbrel-apps).

## Install

See [`INSTALL.md`](./INSTALL.md) for the step-by-step guide (add the community store, install the homeserver, and optionally expose it publicly via Cloudflare Tunnel).

## What's inside

- [`pubky-homeserver/`](./pubky-homeserver) - the Pubky Homeserver app (homeserver + admin dashboard + cloudflared sidecar). Manifest, docker-compose, and any export hooks.
- [`umbrel-app-store.yml`](./umbrel-app-store.yml) - store metadata (`id: pubky`, `name: Pubky`). Umbrel reads this when you add the store.

## Versioning

The app version in `pubky-homeserver/umbrel-app.yml` follows `<homeserver-version>-<packaging-revision>`:

- The base matches the **bundled homeserver's version** (the `pubky-homeserver` crate version at the pinned image's commit), so the store version and the "Homeserver version" shown in the dashboard agree. Same convention as Debian's `upstream-revision` and StartOS's 4th digit.
- The `-N` suffix is the **packaging revision**: bump it for any release that doesn't change the homeserver itself (dashboard updates, compose changes, manifest fixes). First release for a given homeserver is `-1`.
- Examples: homeserver 0.9.1 ships as `0.9.1-1`; a dashboard-only fix follows as `0.9.1-2`; homeserver 0.9.2 resets to `0.9.2-1`.

Rules:

1. **Never publish a bare version** (e.g. `0.9.1` without `-N`). umbreld currently treats any version-string change as an update (`!==` comparison, no ordering), but under strict semver `0.9.1-1` is a *prerelease* of `0.9.1`, i.e. `0.9.1-1 < 0.9.1`. Always suffixing keeps the sequence monotonic under both comparison schemes.
2. **Verify the base version against the pinned image** before releasing: check `pubky-homeserver/Cargo.toml` at the commit the `homeserver` image is pinned to.
3. The dashboard keeps its own independent semver (`v0.1.x` tags + `package.json`, shown in the dashboard footer). The homeserver version is shown on the dashboard's Overview card. The Umbrel app version above ties the two together.

History note: releases up to `0.2.9` used an independent app semver; the scheme above starts at `0.9.1-1`.

## Related projects

- [`pubky/pubky-core`](https://github.com/pubky/pubky-core) - the Rust homeserver this app runs.
- [`pubky/homeserver-dashboard`](https://github.com/pubky/homeserver-dashboard) - the Next.js admin dashboard the app ships with.
- [`pubky/umbrel-apps`](https://github.com/pubky/umbrel-apps) - our fork of the official Umbrel app store used to open the eventual upstream PR.
- [`pubky/umbrel-apps-gallery`](https://github.com/pubky/umbrel-apps-gallery) - fork of the official gallery repo. Hosts `pubky-homeserver/icon.svg` + screenshots; this store's `umbrel-app.yml` points at those raw URLs.

## Reporting issues

Issues with the app packaging (docker-compose, manifest, install flow) go in this repo. Issues with the homeserver itself belong in [`pubky/pubky-core`](https://github.com/pubky/pubky-core/issues); dashboard issues in [`pubky/homeserver-dashboard`](https://github.com/pubky/homeserver-dashboard/issues).
