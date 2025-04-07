#!/bin/bash
# usage: /app/mattermost/bin/run

export MM_PLUGINSETTINGS_CLIENTDIRECTORY="/app/mattermost/client/plugins"
export MM_SERVICESETTINGS_LISTENADDRESS=":${PORT}"

/app/mattermost/bin/mattermost
