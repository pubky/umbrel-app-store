#!/bin/bash

# Export homeserver admin API URL for other apps
export APP_PUBKY_HOMESERVER_ADMIN_URL="http://homeserver:6288"
export APP_PUBKY_HOMESERVER_ADMIN_TOKEN="${APP_PASSWORD:-}"

# Export client API URL
export APP_PUBKY_HOMESERVER_CLIENT_URL="http://homeserver:6286"

# Export metrics URL
export APP_PUBKY_HOMESERVER_METRICS_URL="http://homeserver:6289"

