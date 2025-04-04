#!/bin/bash
# usage: /app/mattermost/bin/postdeploy

export MM_SERVICESETTINGS_LISTENADDRESS=":${PORT}"

echo "postdeploy: Starting"

plugins_list=$(find /app/mattermost/postdeploy_plugins/. -maxdepth 1 -name '*.tar.gz' | tr '\n' ',')
/app/mattermost/bin/mmctl auth login $MATTERMOST_URL --access-token "MATTERMOST_ADMIN_TOKEN"

for plugin in $(echo "$plugins_list" | tr ',' '\n')
do
  echo "postdeploy: Installing plugin $plugin"
  /app/mattermost/bin/mmctl plugin add "$plugin"
done
