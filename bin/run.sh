#!/bin/bash
# usage: /app/mattermost/bin/run

export MM_SERVICESETTINGS_LISTENADDRESS=":${PORT}"
echo lkj $MM_SERVICESETTINGS_LISTENADDRESS

/app/mattermost/bin/mattermost
