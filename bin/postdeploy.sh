#!/bin/bash
# usage: /app/mattermost/bin/postdeploy

export MM_SERVICESETTINGS_LISTENADDRESS=":${PORT}"

echo "postdeploy: Starting"

plugins_list=$(find /app/mattermost/postdeploy_plugins/. -maxdepth 1 -name '*.tar.gz' | tr '\n' ',')

for plugin in $(echo "$plugins_list" | tr ',' '\n')
do
  echo "postdeploy: Installing plugin $plugin"
  tar xzf $plugin --directory /app/mattermost/plugins
done
