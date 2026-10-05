# Docker Compose reference

Your `compose.yaml` starts as a copy of the example Compose file,
[`compose.yaml.example`](../compose.yaml.example). It configures every service
of the setup, and the tables below describe each of its settings.

> [!WARNING]
> Where a setting needs a specific value for the setup to work, its description
> says so. Changes to such settings are unsupported and can break the setup.

## Services

### `database`

The `database` service runs MariaDB with the four VMaNGOS databases: `mangos`
(containing the world data), `characters`, `realmd`, and `logs`.

| Key                 | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `image`             | The Docker image. All client versions use the same database image.                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `restart`           | With `unless-stopped`, Docker restarts the container automatically when it exits and when Docker itself starts, unless you stopped it manually.                                                                                                                                                                                                                                                                                                                                                                                            |
| `stop_grace_period` | `2m` lets a stop during startup wait up to two minutes for the running step, such as a migration, before Docker stops the container forcibly. Docker's default of 10 seconds can cut such a step short.                                                                                                                                                                                                                                                                                                                                    |
| `healthcheck`       | Sets the container's status to `healthy` or `unhealthy`, to indicate whether something is wrong. `test` runs the image's own check, and has to stay as it is. `start_period: 24h` keeps the container in the `starting` state, and prevents it from switching to `unhealthy`, during the two phases that can take long: the first start, which imports the world data, and a halt for changes you apply by hand (see the [migration edits section](usage.md#migration-edits)). Lower it if you want Docker to report a stuck start sooner. |
| `volumes`           | `vmangos-database` is a named volume that holds the databases. The top-level `volumes` declares it, and Docker creates it on the first start and keeps it until you delete it. `storage/database/custom-sql/` holds your own SQL files for the world database, read-only. See the [custom SQL section](usage.md#custom-sql). The paths inside the container, right of the colon, have to stay as they are.                                                                                                                                 |
| `environment`       | The variables in the table below.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |

The `environment` of `database` has:

| Variable                                        | Default     | Description                                                                                                                                                                                                                                                                                                                                                                                 |
| ----------------------------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `VMANGOS_DEPLOY_VERSION`                        | Required    | The number that the image checks on startup. See the [`VMANGOS_DEPLOY_VERSION` section](#vmangos_deploy_version).                                                                                                                                                                                                                                                                           |
| `TZ`                                            | `Etc/UTC`   | The time zone of the service, such as `Europe/Vienna`. You usually want to set this to your host's time zone.                                                                                                                                                                                                                                                                               |
| `MARIADB_USER`                                  | `mangos`    | The user that `realmd` and `mangosd` connect with. It has to match `VMANGOS_DATABASE_USER` of those services. See the [database users section](#database-users).                                                                                                                                                                                                                            |
| `MARIADB_PASSWORD`                              | `mangos`    | The password of that user. It has to match `VMANGOS_DATABASE_PASSWORD` of `realmd` and `mangosd`. See the [database users section](#database-users).                                                                                                                                                                                                                                        |
| `MARIADB_ROOT_PASSWORD`                         | `password`  | The password of the database's `root` user, which the setup scripts, the optional services, and you use. See the [database users section](#database-users).                                                                                                                                                                                                                                 |
| `VMANGOS_REALMLIST_NAME`                        | `VMaNGOS`   | The realm's name in the realm list and on the character screen. See the [realm list section](#realm-list).                                                                                                                                                                                                                                                                                  |
| `VMANGOS_REALMLIST_ADDRESS`                     | `127.0.0.1` | The address clients connect to. Keep `127.0.0.1` to play on the host itself. To connect from another machine, set a LAN address, a WAN address, or a domain name. See the [realm list section](#realm-list).                                                                                                                                                                                |
| `VMANGOS_REALMLIST_PORT`                        | `8085`      | The host port number of the `mangosd` service, left of the colon in its port mapping. See the [realm list section](#realm-list).                                                                                                                                                                                                                                                            |
| `VMANGOS_REALMLIST_ICON`                        | `1`         | The realm icon in the realm list: `0` is Normal, `1` is PvP, `6` is RP, and `8` is RP PvP. It sets only the icon. `GameType` in your `config/mangosd.conf` sets the actual realm type. The default matches the `GameType` of the example configuration file. See the [realm list section](#realm-list).                                                                                     |
| `VMANGOS_REALMLIST_TIMEZONE`                    | `0`         | The realm's region in the realm list. Common values are `2` for United States, `3` for Oceanic, `4` for Latin America, `8` for English, `9` for German, `10` for French, `11` for Spanish, and `12` for Russian. See the [realm list section](#realm-list).                                                                                                                                 |
| `VMANGOS_REALMLIST_ALLOWED_SECURITY_LEVEL`      | `0`         | The lowest account level that can log in. `0` admits regular players. See the [realm list section](#realm-list).                                                                                                                                                                                                                                                                            |
| `VMANGOS_ENABLE_AUTOMATIC_WORLD_DB_CORRECTIONS` | `1`         | With `1`, the database re-creates the world database to apply a migration edit. With `0`, the edit is handled like one to a database with player data. It is recommended to keep it at `1`, unless you have a specific reason to change it. See the [migration edits section](usage.md#migration-edits).                                                                                    |
| `VMANGOS_HALT_ON_MIGRATION_EDITS`               | `1`         | With `1`, the start halts until you apply a migration edit to a database with player data by hand and confirm it. With `0`, the database logs a warning on every start and continues, which leaves the database in an inconsistent state. It is recommended to keep it at `1`, unless you have a specific reason to change it. See the [migration edits section](usage.md#migration-edits). |
| `VMANGOS_PROCESS_CUSTOM_SQL`                    | `1`         | With `1`, the database runs every `.sql` file in `storage/database/custom-sql/` on every start. `0` disables it. See the [custom SQL section](usage.md#custom-sql).                                                                                                                                                                                                                         |

### `realmd`

The `realmd` service runs the login server.

| Key           | Description                                                                                                                                                                                                                                                                                                           |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `image`       | The Docker image. Its tag indicates the client version, such as `ghcr.io/mserajnik/vmangos-server:5875`. The [client versions section](usage.md#client-versions) lists the available images.                                                                                                                          |
| `command`     | `realmd` selects the login server. It has to stay as it is.                                                                                                                                                                                                                                                           |
| `depends_on`  | `realmd` starts once the healthcheck of the `database` service passes. It has to stay as it is.                                                                                                                                                                                                                       |
| `restart`     | With `unless-stopped`, Docker restarts the container automatically when it exits and when Docker itself starts, unless you stopped it manually.                                                                                                                                                                       |
| `healthcheck` | Sets the container's status to `healthy` or `unhealthy`, to indicate whether something is wrong. The port in `test` has to match the container port number in the port mapping. `start_period: 5m` prevents a failing healthcheck during the first five minutes after a start from setting the status to `unhealthy`. |
| `ports`       | The port mapping of the login server. To use another port on the host, change the host port number, left of the colon. The container port number, right of the colon, has to stay `3724`.                                                                                                                             |
| `volumes`     | `config/realmd.conf` is your configuration file, read-only, and `storage/realmd/logs/` receives the log files. The paths inside the container, right of the colon, have to stay as they are.                                                                                                                          |
| `environment` | The variables in the table below.                                                                                                                                                                                                                                                                                     |

The `environment` of `realmd` and `mangosd` has:

| Variable                    | Default   | Description                                                                                                       |
| --------------------------- | --------- | ----------------------------------------------------------------------------------------------------------------- |
| `VMANGOS_DEPLOY_VERSION`    | Required  | The number that the image checks on startup. See the [`VMANGOS_DEPLOY_VERSION` section](#vmangos_deploy_version). |
| `VMANGOS_UID`               | `1000`    | The UID the server runs as. See the [user and group section](#user-and-group).                                    |
| `VMANGOS_GID`               | `1000`    | The GID the server runs as. See the [user and group section](#user-and-group).                                    |
| `VMANGOS_DATABASE_USER`     | Required  | The user the server connects to the `database` service with. It has to match `MARIADB_USER` of that service.      |
| `VMANGOS_DATABASE_PASSWORD` | Required  | The password of that user. It has to match `MARIADB_PASSWORD` of the `database` service.                          |
| `TZ`                        | `Etc/UTC` | The time zone of the service, such as `Europe/Vienna`. You usually want to set this to your host's time zone.     |

### `mangosd`

The `mangosd` service runs the world server.

| Key                    | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `image`                | The Docker image, the same as for `realmd`. The anchor `&mangosd-image` passes it on to the tools, and has to stay.                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `command`              | `mangosd` selects the world server. It has to stay as it is.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `tty` and `stdin_open` | With `true`, they let you attach to the server console with `docker compose attach mangosd`, to run commands such as creating accounts.                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `depends_on`           | `mangosd` starts once the healthcheck of the `database` service passes. It has to stay as it is.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `restart`              | With `unless-stopped`, Docker restarts the container automatically when it exits and when Docker itself starts, unless you stopped it manually.                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `stop_grace_period`    | `2m` gives the server two minutes to save during shutdown before Docker stops it forcibly. Docker's default of 10 seconds can be too short for a busy server.                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `healthcheck`          | Sets the container's status to `healthy` or `unhealthy`, to indicate whether something is wrong. The port in `test` has to match the container port number of the world server in the port mapping. `start_period: 5m` prevents a failing healthcheck during the first five minutes after a start from setting the status to `unhealthy`.                                                                                                                                                                                                                                                         |
| `ports`                | The port mapping of the world server, and the commented-out mappings of SOAP and the remote console. To use another port on the host, change the host port number, left of the colon, and for the world server, also set `VMANGOS_REALMLIST_PORT` to that number. The container port numbers, right of the colon, have to stay as they are. To use SOAP, set `SOAP.Enabled = 1` in your `config/mangosd.conf` and uncomment the `7878:7878` port mapping. To use the remote console, set `Ra.Enable = 1` and uncomment the `3443:3443` port mapping.                                              |
| `volumes`              | `config/mangosd.conf` is your configuration file, read-only. `storage/mangosd/extracted-data/` holds the extracted client data, read-only (see the [extracting the client data section](usage.md#extracting-the-client-data)). `storage/mangosd/logs/` receives the log files, and `storage/mangosd/honor/` the weekly honor calculation reports. `storage/mangosd/warden-modules/` holds the Warden modules, once you uncomment its mount (see the [anticheat and Warden section](usage.md#anticheat-and-warden)). The paths inside the container, right of the colon, have to stay as they are. |
| `environment`          | The same variables as `realmd`, in the table above. The anchor `&mangosd-environment` passes them on to the tools, and has to stay.                                                                                                                                                                                                                                                                                                                                                                                                                                                               |

### `check-deploy-version`

The `check-deploy-version` service checks whether you have to make adjustments
for a breaking change, as the [updating section](usage.md#updating) describes.

| Key           | Description                                                                                                                                               |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `image`       | The image of `mangosd`, through the alias `*mangosd-image`, so it checks the image that `mangosd` runs. It has to stay as it is.                          |
| `profiles`    | With `['tools']`, `docker compose up` does not start the service, because it only runs on demand, to check for breaking changes. It has to stay as it is. |
| `entrypoint`  | Runs the check. It has to stay as it is.                                                                                                                  |
| `environment` | The environment of `mangosd`, through the alias `*mangosd-environment`. It has to stay as it is.                                                          |

### `extract-client-data`

The `extract-client-data` service extracts the client data, as the
[extracting the client data section](usage.md#extracting-the-client-data)
describes.

| Key           | Description                                                                                                                                                                                                            |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `image`       | The image of `mangosd`, through the alias `*mangosd-image`, so the extracted data matches the client version of `mangosd`. It has to stay as it is.                                                                    |
| `profiles`    | With `['tools']`, `docker compose up` does not start the service, because it only runs on demand, to extract the client data. It has to stay as it is.                                                                 |
| `entrypoint`  | Runs the extraction. It has to stay as it is.                                                                                                                                                                          |
| `volumes`     | `storage/mangosd/client-data/` holds the client data to extract from, and `storage/mangosd/extracted-data/` receives the extracted data. The paths inside the container, right of the colon, have to stay as they are. |
| `environment` | The environment of `mangosd`, through the alias `*mangosd-environment`. The service runs as the same user. It has to stay as it is.                                                                                    |

### `database-backup` (optional)

This service creates a backup of the character and account databases,
`characters` and `realmd`, and of the migration edit ledger in `maintenance`,
every day at 04:00, and deletes the backups older than a week. To use it,
uncomment it. Each backup is one `.tgz` archive in `storage/database/backups/`
with one SQL dump per database. The [backups section](usage.md#backups)
describes on-demand backups and restoring.

| Key           | Description                                                                                                                                     |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `image`       | The service uses the [`databack/mysql-backup`][mysql-backup] image.                                                                             |
| `user`        | The UID and GID the service runs as. The image has no UID and GID variables, so on Linux, set it to the owner of `storage/database/backups/`.   |
| `command`     | `dump` creates backups on the schedule. It has to stay as it is.                                                                                |
| `depends_on`  | The service starts once the healthcheck of the `database` service passes. It has to stay as it is.                                              |
| `restart`     | With `unless-stopped`, Docker restarts the container automatically when it exits and when Docker itself starts, unless you stopped it manually. |
| `volumes`     | `storage/database/backups/` receives the backups. The path inside the container, right of the colon, has to stay as it is.                      |
| `environment` | The variables in the table below.                                                                                                               |

The `environment` of `database-backup` has:

| Variable              | Default                         | Description                                                                                                                                           |
| --------------------- | ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `TZ`                  | `Etc/UTC`                       | The time zone of the service, such as `Europe/Vienna`. It does not affect the schedule, which `DB_DUMP_CRON` configures separately.                   |
| `DB_SERVER`           | `database`                      | The host name of the `database` service in the Compose network. It has to stay as it is.                                                              |
| `DB_USER`             | `root`                          | The user the service connects with. With `root`, it can read every database. It has to stay as it is.                                                 |
| `DB_PASS`             | `password`                      | The password of that user. It has to match `MARIADB_ROOT_PASSWORD` of the `database` service.                                                         |
| `DB_DUMP_INCLUDE`     | `characters,realmd,maintenance` | The databases to back up. The world database is left out, because the image can re-create it, apart from the event progress in its `variables` table. |
| `DB_DUMP_TARGET`      | `/backup`                       | The directory inside the container that receives the backups. It has to stay as it is.                                                                |
| `DB_DUMP_COMPRESSION` | `gzip`                          | The compression of the archives.                                                                                                                      |
| `DB_DUMP_CRON`        | `CRON_TZ=Etc/UTC 0 4 * * *`     | The schedule, in cron syntax. `CRON_TZ` sets the time zone the schedule runs in, and `TZ` does not affect it, so keep the two in step.                |
| `DB_DUMP_RETENTION`   | `7d`                            | How old a backup gets before the service deletes it. `7d` is a week.                                                                                  |
| `DB_DUMP_SAFECHARS`   | `true`                          | With `true`, it keeps colons out of the file names by writing hyphens, which Windows needs.                                                           |

### `phpmyadmin` (optional)

This service runs [phpMyAdmin][phpmyadmin], a web interface for the databases,
at `http://localhost:8080`. To use it, uncomment it.

| Key           | Description                                                                                                                                                                                                                                                                                               |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `image`       | The service uses the [`phpmyadmin`][phpmyadmin-image] image.                                                                                                                                                                                                                                              |
| `depends_on`  | The service starts once the healthcheck of the `database` service passes. It has to stay as it is.                                                                                                                                                                                                        |
| `restart`     | With `unless-stopped`, Docker restarts the container automatically when it exits and when Docker itself starts, unless you stopped it manually.                                                                                                                                                           |
| `ports`       | The port mapping of the web interface. To use another port on the host, change the host port number, left of the colon. The container port number, right of the colon, has to stay `80`. Do not expose the port to the internet, as the [database security section](usage.md#database-security) explains. |
| `environment` | The variables in the table below.                                                                                                                                                                                                                                                                         |

The `environment` of `phpmyadmin` has:

| Variable       | Default    | Description                                                                                   |
| -------------- | ---------- | --------------------------------------------------------------------------------------------- |
| `PMA_HOST`     | `database` | The host name of the `database` service in the Compose network. It has to stay as it is.      |
| `PMA_PORT`     | `3306`     | The port of MariaDB in the `database` service. It has to stay as it is.                       |
| `PMA_USER`     | `root`     | The user phpMyAdmin logs in as.                                                               |
| `PMA_PASSWORD` | `password` | The password of that user. It has to match `MARIADB_ROOT_PASSWORD` of the `database` service. |

## `VMANGOS_DEPLOY_VERSION`

The `database`, `realmd`, and `mangosd` services each set
`VMANGOS_DEPLOY_VERSION`. Every Docker image expects a specific number there
and refuses to start with any other value, a missing one included. When a new
image changes something that you have to act on, the number it expects
increases by one, and the [breaking changes documentation](breaking-changes.md)
lists what to change before you raise the number in your `compose.yaml` to
match.

## User and group

The `realmd` and `mangosd` containers start as root and switch to a user with
the UID and GID from `VMANGOS_UID` and `VMANGOS_GID`. Files the servers write
belong to that user. Setting `user` instead stops the containers with an error.

On Linux, set both to the owner of the writable bind mounts, which is usually
your own user. Changing `VMANGOS_UID` and `VMANGOS_GID` once the server has run
also requires changing the owner of the directories on the host, for example
with `sudo chown -R 1001:1001 storage/mangosd/logs`. Without that, the server
can no longer write to the files it created.

What needs which owner:

- The writable bind mounts, such as `storage/realmd/logs/` and
  `storage/mangosd/logs/`, need to belong to the configured UID and GID.
- The read-only bind mounts, such as the configuration files and
  `storage/mangosd/extracted-data/`, only need to be readable.
- Docker sets up the named volume of the `database` service by itself.

On macOS, Docker maps the owner of bind-mounted files, and the default values
work. On Windows, an installation on a Windows drive behaves the same way. An
installation inside the Linux file system of WSL 2 follows the rules for Linux.

## Database users

`MARIADB_USER`, `MARIADB_PASSWORD`, and `MARIADB_ROOT_PASSWORD` take effect on
the first start only, when MariaDB creates the users. To change a user or a
password later, change it in the database, for example with the optional
`phpmyadmin` service, and then in your `compose.yaml`.

## Realm list

The `VMANGOS_REALMLIST_*` variables set the realm entry that the game client
shows. The database writes them into `realmd.realmlist` on every start. A
change applies once `docker compose up -d` re-creates the container, and
overwrites any edit you made to these columns in the database. The other
columns stay as you set them.

[mysql-backup]: https://hub.docker.com/r/databack/mysql-backup
[phpmyadmin]: https://www.phpmyadmin.net/
[phpmyadmin-image]: https://hub.docker.com/_/phpmyadmin
