# mattermost-buildpack

> This buildpack aims at installing a [Mostlymatter](https://framagit.org/framasoft/framateam/mostlymatter) instance on [Scalingo](https://www.scalingo.com) and let you configure it at your convenance.

Mostlymatter is a fork of the Mattermost open source edition maintained by Framasoft, without the user and message limits. The buildpack downloads:

- the `mattermost-team` release tarball from `releases.mattermost.com` (web client, i18n, templates, `mmctl`);
- the matching `mostlymatter` binary from `packages.framasoft.org` (checksum verified), which replaces the Mattermost server binary (`bin/mattermost` is a symlink to `bin/mostlymatter`).

## Usage

Simply deploy by cliking on this button:

[![Deploy to Scalingo](https://cdn.scalingo.com/deploy/button.svg)](https://my.scalingo.com/deploy?source=https://github.com/MTES-MCT/mattermost-scalingo#main)

Or create an app. You must have an add-on database `postgresql` or `mysql`.
[Add this buildpack environment variable][1] to your Scalingo application to install the `Mattermost` server:

```shell
BUILDPACK_URL=https://github.com/MTES-MCT/mattermost-buildpack#main
```

And other environment variables are set by example in a `.env.sample` file.

`PORT` and `SCALINGO_POSTGRESQL_URL` are provided by Scalingo.

Addon configuration by default:

```shell
MM_SQLSETTINGS_DRIVERNAME=postgres # if required replace by mysql
MM_SQLSETTINGS_DATASOURCE=$SCALINGO_POSTGRESQL_URL # SCALINGO_POSTGRESQL_URL is provided by scalingo at app boot step
```

Warning ⚠️: you should copy the database url in `MM_SQLSETTINGS_DATASOURCE` and change `sslmode` if `prefer` is unknown by mattermost.

Version installed (default `12.1.0`). It must be published both by [Framasoft](https://packages.framasoft.org/projects/mostlymatter/) and by Mattermost:

```shell
MATTERMOST_VERSION=12.1.0
```

`MATTERMOST_EDITION` is no longer used: mostlymatter is built from the open source edition.

All other environment variables are specific to mattermost, see [documentation](https://docs.mattermost.com/administration/config-settings.html#environment-variables).

You can also persist your config in each build and deploy:

```shell
MM_CONFIG=$SCALINGO_POSTGRESQL_URL # persists config in database
```

You can list plugins to install at build:

```shell
## From marketplace set ids
MATTERMOST_MARKETPLACE_PLUGINS=com.github.matterpoll.matterpoll,memes
## From Github set owner/repo (latest release) or owner/repo@tag (pinned release)
MATTERMOST_GITHUB_PLUGINS=mattermost/mattermost-plugin-boards@v10.1.0,mattermost-community/mattermost-plugin-welcomebot
```

For Github releases, the `linux-<arch>` tarball is preferred, then a multi-platform tarball; FIPS builds are skipped.

`MATTERMOST_PREPACKAGED_PLUGINS` is no longer supported: recent `mattermost-team` tarballs do not ship prepackaged plugins. Use `MATTERMOST_GITHUB_PLUGINS` instead, e.g. `mattermost/mattermost-plugin-boards` for Boards.

## Hacking

You set environment variables in `.env`:

```shell
cp .env.sample .env
```

Run an interactive docker scalingo stack:

```shell
docker run --name mattermost -it -p 8065:8065 -v "$(pwd)"/.env:/env/.env -v "$(pwd)":/buildpack scalingo/scalingo-22:latest bash
```

And test in it:

```shell
bash buildpack/bin/detect
bash buildpack/bin/env.sh /env/.env /env
bash buildpack/bin/compile /build /cache /env
bash buildpack/bin/release
```

Run Mattermost server:

```shell
export PATH=$PATH:/build/mattermost/bin
mostlymatter server
```

You can also use docker-compose in order to test with a complete stack (db, s3, smtp):

```shell
docker-compose up --build -d
```

You can test postdeploy (install plugins list):

```shell
bash /app/mattermost/bin/postdeploy
```

`.env.sample` is configured to work with this stack. You just need to create the bucket `mattermost` in minio.

[1]: https://doc.scalingo.com/platform/deployment/buildpacks/custom
