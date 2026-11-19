#!/bin/bash
# usage: /app/mattermost/bin/run

export MM_PLUGINSETTINGS_CLIENTDIRECTORY="/app/mattermost/client/plugins"
export MM_SERVICESETTINGS_LISTENADDRESS=":${PORT}"
# Install enabled plugins from prepackaged_plugins at boot (dist and buildpack plugins)
export MM_PLUGINSETTINGS_AUTOMATICPREPACKAGEDPLUGINS="${MM_PLUGINSETTINGS_AUTOMATICPREPACKAGEDPLUGINS:-true}"

# Default to the Scalingo PostgreSQL addon, app env vars take precedence
export MM_SQLSETTINGS_DRIVERNAME="${MM_SQLSETTINGS_DRIVERNAME:-postgres}"
export MM_SQLSETTINGS_DATASOURCE="${MM_SQLSETTINGS_DATASOURCE:-$SCALINGO_POSTGRESQL_URL}"
# Persist config in database, the container filesystem is ephemeral
export MM_CONFIG="${MM_CONFIG:-$MM_SQLSETTINGS_DATASOURCE}"

exec /app/mattermost/bin/mostlymatter
