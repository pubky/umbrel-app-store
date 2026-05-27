# Pubky Umbrel App Store

A community [Umbrel](https://umbrel.com) app store that hosts the **Pubky Homeserver** for self-hosted Pubky users while the app is in beta.

Once the app graduates from beta, it will also be available directly from the official [Umbrel App Store](https://github.com/getumbrel/umbrel-apps).

## Install

1. In umbrelOS, open the **App Store**.
2. Click your username (top-right) → **Community App Stores** → **Add a Community App Store**.
3. Paste this repo's URL:

   ```
   https://github.com/pubky/umbrel-app-store
   ```

4. The **Pubky** store appears in the App Store sidebar. Open it and install **Pubky Homeserver**.

## What's inside

- [`pubky-homeserver/`](./pubky-homeserver) — the Pubky Homeserver app (homeserver + admin dashboard + cloudflared sidecar). Manifest, docker-compose, and any export hooks.
- [`umbrel-app-store.yml`](./umbrel-app-store.yml) — store metadata (`id: pubky`, `name: Pubky`). Umbrel reads this when you add the store.

## Related projects

- [`pubky/pubky-core`](https://github.com/pubky/pubky-core) — the Rust homeserver this app runs.
- [`pubky/homeserver-dashboard`](https://github.com/pubky/homeserver-dashboard) — the Next.js admin dashboard the app ships with.
- [`pubky/umbrel-apps`](https://github.com/pubky/umbrel-apps) — our fork of the official Umbrel app store used to open the eventual upstream PR.

## Reporting issues

Issues with the app packaging (docker-compose, manifest, install flow) go in this repo. Issues with the homeserver itself belong in [`pubky/pubky-core`](https://github.com/pubky/pubky-core/issues); dashboard issues in [`pubky/homeserver-dashboard`](https://github.com/pubky/homeserver-dashboard/issues).
