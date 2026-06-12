# Install Pubky Homeserver on Umbrel

## 1. Add this community app store

1. Click the **App Store** icon on your Umbrel home screen.
2. Top-right, click the **`...`** (three dots) → **Community App Stores**.
3. Paste:
   ```
   https://github.com/pubky/umbrel-app-store
   ```
4. Click **Add**.

## 2. Install the Pubky Homeserver

1. Click **Open** on the **Pubky** community app store.
2. Click **Pubky Homeserver** → **Install**.
3. Wait for the install to finish.

When done, the Pubky Homeserver tile appears on your Umbrel home screen. Click it to open the admin dashboard.

## 3. (Optional) Expose your homeserver to the public internet

A homeserver behind your home NAT can only be reached from your LAN unless you expose it publicly. Open the dashboard, click the **gear icon** (Settings), switch to the **Cloudflare** tab, and pick one of four ways:

- **Connect Cloudflare account** (recommended): click Connect, log in on cloudflare.com, click Authorize, type your hostname. Nothing to copy or paste. Needs a free Cloudflare account and a domain.
- **API token**: paste a narrowly-scoped Cloudflare API token (pre-filled creation link provided), pick your domain, click Create.
- **Preview mode**: no account and no domain at all - one click gives you a temporary public address, published to the Pubky network and refreshed on every restart. The limitations are listed on the card; use it for trying things out, not production.
- **Manual setup**: the classic flow, with a full step-by-step guide linked below the form and from the dashboard footer.

The Overview shows live whether your published domain is reachable, with a Fix it button if it is not.

## Reporting issues

- App packaging (this repo): https://github.com/pubky/umbrel-app-store/issues
- Homeserver: https://github.com/pubky/pubky-core/issues
- Dashboard: https://github.com/pubky/homeserver-dashboard/issues
