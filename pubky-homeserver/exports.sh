#!/bin/bash

# URLs other Umbrel apps can use to reach this homeserver. No consumer
# apps exist today; these are best-effort.
#
# Two pitfalls for whoever adds a consumer app later:
#
# 1. umbreld sources this file while starting EVERY app, with THAT app's
#    environment. Variables like APP_PASSWORD therefore belong to the app
#    being started, not to this one, so nothing here may be derived from
#    them. (An earlier version exported an admin token from
#    ${APP_PASSWORD:-}, which yielded the consumer app's password.) The
#    admin API still requires this app's APP_PASSWORD as the token; a
#    consumer must obtain it out of band (e.g. the user pastes it).
#
# 2. Compose service aliases like "homeserver" only resolve inside this
#    app's own network. From other apps, use the static container name
#    (umbrel project naming: <app-id>_<service>_1) below.

# Admin API (requires this app's APP_PASSWORD, see above)
export APP_PUBKY_HOMESERVER_ADMIN_URL="http://pubky-homeserver_homeserver_1:6288"

# Client API
export APP_PUBKY_HOMESERVER_CLIENT_URL="http://pubky-homeserver_homeserver_1:6286"

# Metrics (unauthenticated; container network only, not published to the host)
export APP_PUBKY_HOMESERVER_METRICS_URL="http://pubky-homeserver_homeserver_1:6289"
