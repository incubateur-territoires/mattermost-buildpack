#!/bin/bash

steptxt="----->"
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'                              # No Color
CURL="curl -L --retry 15 --retry-delay 2" # retry for up to 30 seconds

info() {
  echo -e "${GREEN}       $*${NC}"
}

warn() {
  echo -e "${YELLOW} !!    $*${NC}"
}

err() {
  echo -e "${RED} !!    $*${NC}" >&2
}

step() {
  echo "$steptxt $*"
}

start() {
  echo -n "$steptxt $*... "
}

finished() {
  echo "done"
}

function indent() {
  c='s/^/       /'
  case $(uname) in
  Darwin) sed -l "$c" ;; # mac/bsd sed: -l buffers on line boundaries
  *) sed -u "$c" ;;      # unix/gnu sed: -u unbuffered (arbitrary) chunks of data
  esac
}

function detect_arch() {
  case "$(uname -m)" in
  x86_64 | amd64) echo "amd64" ;;
  aarch64 | arm64) echo "arm64" ;;
  *)
    err "Unsupported architecture: $(uname -m)"
    return 1
    ;;
  esac
}

function install_jq() {
  if command -v jq >/dev/null 2>&1; then
    info "jq already available: $(jq --version)"
    return 0
  fi
  if [[ -f "${ENV_DIR}/JQ_VERSION" ]]; then
    JQ_VERSION=$(cat "${ENV_DIR}/JQ_VERSION")
  else
    JQ_VERSION=1.7.1
  fi
  step "Fetching jq $JQ_VERSION"
  if [ -f "${CACHE_DIR}/dist/jq-$JQ_VERSION-$ARCH" ]; then
    info "File already downloaded"
  else
    ${CURL} -o "${CACHE_DIR}/dist/jq-$JQ_VERSION-$ARCH" "https://github.com/jqlang/jq/releases/download/jq-$JQ_VERSION/jq-linux-$ARCH"
  fi
  cp "${CACHE_DIR}/dist/jq-$JQ_VERSION-$ARCH" "${BUILD_DIR}/bin/jq"
  chmod +x "${BUILD_DIR}/bin/jq"
  finished
}

function install_plugin() {
  local location="$1"
  local plugin_url="$2"
  local plugin_package
  plugin_package=$(echo "$plugin_url" | rev | cut -d '/' -f 1 | rev)
  if [ -f "${CACHE_DIR}/dist/plugins/${plugin_package}" ]; then
    info "$plugin_package is already downloaded in cache"
  else
    ${CURL} -o "${CACHE_DIR}/dist/plugins/$plugin_package" "$plugin_url"
  fi
  unpack_plugin "$location" "${CACHE_DIR}/dist/plugins/${plugin_package}"
  info "Plugin $plugin_package installed in $location"
}

function unpack_plugin() {
  local location="$1"
  local plugin_file="$2"

  tar xvf "$plugin_file" --directory "$location"
}

# usage: fetch_github_release owner/repo[@tag]
# Prints the plugin tarball url of the given release (latest by default).
# Prefers the linux-$ARCH build, falls back to a multi-platform tarball, skips FIPS builds.
function fetch_github_release() {
  local repo="${1%%@*}"
  local release="latest"
  if [[ "$1" == *@* ]]; then
    release="tags/${1#*@}"
  fi
  local http_code
  http_code=$($CURL -G -o "$TMP_PATH/release.json" -w '%{http_code}' -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/${repo}/releases/${release}")
  if [[ $http_code == 200 ]]; then
    jq -r --arg arch "$ARCH" '
      [.assets[] | select(.name | test("\\.tar\\.gz$")) | select(.name | test("fips"; "i") | not)] as $assets
      | [($assets[] | select(.name | test("linux[_-]" + $arch; "i"))),
         ($assets[] | select(.name | test("(linux|darwin|windows)[_-]"; "i") | not))]
      | first | .browser_download_url // empty' "$TMP_PATH/release.json"
  fi
}

function install_github_plugins_list() {
  local location="$1"
  local plugins_list="$2"
  info "Plugins list to install: ${plugins_list}"
  local plugin_url
  for plugin_id in $(echo "$plugins_list" | tr ',' '\n'); do
    plugin_url=$(fetch_github_release "$plugin_id")
    info "Plugin id to install: ${plugin_id}"
    if [[ -n $plugin_url ]]; then
      install_plugin "$location" "$plugin_url"
    else
      warn "No plugin release found in Github for $plugin_id"
    fi
  done
}

function install_marketplace_plugins_list() {
  local location="$1"
  local server_version="$2"
  local plugins_list="$3"
  info "Plugins list to install: ${plugins_list}"
  local http_code
  http_code=$($CURL -G -o "$TMP_PATH/plugins.json" -w '%{http_code}' -H "Accept: application/json" "https://api.integrations.mattermost.com/api/v1/plugins?platform=linux-$ARCH&server_version=$server_version")
  local plugin_url
  if [[ $http_code == 200 ]]; then
    for plugin_id in $(echo "$plugins_list" | tr ',' '\n'); do
      info "Plugin id to install: ${plugin_id}"
      plugin_url=$(cat "$TMP_PATH/plugins.json" | jq --arg id "$plugin_id" '.[] | select(.manifest.id == $id) | .download_url')
      plugin_url="${plugin_url%\"}"
      plugin_url="${plugin_url#\"}"
      if [[ -n $plugin_url ]]; then
        install_plugin "$location" "$plugin_url"
      else
        warn "No plugin with id $plugin_id found in marketplace"
      fi
    done
  else
    warn "No plugins list found in marketplace"
  fi
}

function fix_plugin_ids() {
  local location="$1"
  for plugin_config in $(find "$location" -name "plugin.json"); do
    plugin_id="$(cat "$plugin_config" | jq -r '.id')"
    old_plugin_dir="$(dirname "$plugin_config")"
    new_plugin_dir="$location/$plugin_id"
    if [ "$old_plugin_dir" != "$new_plugin_dir" ]; then
      info "$old_plugin_dir moved to $new_plugin_dir"
      mv "$old_plugin_dir" "$new_plugin_dir"
    fi
  done
}

# Mattermost team tarball: provides client, i18n, templates, fonts and mmctl.
# Its server binary is replaced by mostlymatter.
function fetch_mattermost_dist() {
  local version="$1"
  local location="$2"
  local dist="mattermost-team-${version}-linux-${ARCH}.tar.gz"
  local dist_url="https://releases.mattermost.com/${version}/${dist}"
  if [ -f "${CACHE_DIR}/dist/${dist}" ]; then
    info "File is already downloaded"
  else
    ${CURL} --fail -o "${CACHE_DIR}/dist/${dist}" "${dist_url}"
  fi
  tar xzf "$CACHE_DIR/dist/${dist}" -C "$location"
}

# Mostlymatter server binary built by Framasoft: https://framagit.org/framasoft/framateam/mostlymatter
function fetch_mostlymatter() {
  local version="$1"
  local destination="$2"
  local binary="mostlymatter-${ARCH}-v${version}"
  local base_url="https://packages.framasoft.org/projects/mostlymatter"
  if [ -f "${CACHE_DIR}/dist/${binary}" ]; then
    info "File is already downloaded"
  else
    ${CURL} --fail -o "${CACHE_DIR}/dist/${binary}.sha512" "${base_url}/${binary}.sha512"
    ${CURL} --fail -o "${CACHE_DIR}/dist/${binary}" "${base_url}/${binary}"
  fi
  if ! (cd "${CACHE_DIR}/dist" && sha512sum --check --status "${binary}.sha512"); then
    rm -f "${CACHE_DIR}/dist/${binary}" "${CACHE_DIR}/dist/${binary}.sha512"
    err "Checksum mismatch for ${binary}"
    return 1
  fi
  info "Checksum verified for ${binary}"
  cp "${CACHE_DIR}/dist/${binary}" "$destination"
  chmod +x "$destination"
}
