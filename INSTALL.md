# Install Pubky Homeserver on Umbrel

## 1. Add this community app store

1. In umbrelOS, open the **App Store**.
2. Click your username (top-right) → **Community App Stores** → **Add a Community App Store**.
3. Paste:
   ```
   https://github.com/pubky/umbrel-app-store
   ```
4. Click **Add**.

The **Pubky** store appears in the App Store sidebar.

## 2. Install the Pubky Homeserver

1. Open the **Pubky** store from the sidebar.
2. Click **Pubky Homeserver** → **Install**.
3. Wait for the install to finish.

When done, the Pubky Homeserver tile appears on your Umbrel home screen. Click it to open the admin dashboard.

## 3. (Optional) Expose your homeserver to the public internet

A homeserver behind your home NAT can only be reached from your LAN unless you expose it publicly. The easiest way is a Cloudflare Tunnel (free, no port forwarding).

The dashboard ships with a built-in setup guide:

1. Open the homeserver dashboard.
2. Click the **gear icon** (Settings) in the top-right.
3. Switch to the **Cloudflare** tab.
4. Click **Full setup guide** below the Save button.

The guide walks through Cloudflare-side setup (creating the tunnel, getting the token), dashboard-side configuration, and verification. It is also linked from the dashboard footer.

## Reporting issues

- App packaging (this repo): https://github.com/pubky/umbrel-app-store/issues
- Homeserver: https://github.com/pubky/pubky-core/issues
- Dashboard: https://github.com/pubky/homeserver-dashboard/issues
