# vmangos-deploy

[![Latest built VMaNGOS commit][badge-latest-vmangos-commit]][badge-latest-vmangos-commit-url] [![Latest build date][badge-latest-build-date]][badge-latest-build-date-url] [![GitHub Actions status][badge-actions-status]][badge-actions-status-url]

> A Docker setup for VMaNGOS

This is a Docker-based solution for running [VMaNGOS][vmangos] that focuses on
providing a streamlined and user-friendly experience. It offers a range of
features that simplify managing a VMaNGOS setup:

+ __Prebuilt Docker images for both `x86_64` and `aarch64`, leveraging GitHub__
  __Actions:__ simply pull the provided images that have been optimized for
  size, performance and stability instead of having to re-compile VMaNGOS
  yourself every time you want to update
+ __The ability to run VMaNGOS configured for any of its supported client__
  __versions:__ prebuilt images for all versions ranging from `1.6.1.4544` to
  `1.12.1.5875` are provided
+ __Seamless, automated database migrations:__ when pulling the latest Docker
  images and re-creating the containers, migrations are applied automatically
  to keep your database up-to-date at all times
+ __A transparent and easy-to-follow user experience:__ the number of different
  commands that need to be run to install and manage VMaNGOS is kept to a
  minimum. You can use the Docker CLI or any other tool that is able to manage
  Docker containers
+ __A clean and organized structure:__ the VMaNGOS configuration can be found
  in [`./config`](config), everything else that is shared between the Docker
  containers and your host system lives inside [`./storage`](storage)

> [!NOTE]
> The Docker images are built on a daily schedule, unless there have been no
> new commits to VMaNGOS since the last build. Additionally, every Monday, the
> latest images are rebuilt to ensure software and dependencies are up-to-date,
> even if there have been no updates to VMaNGOS itself.

## Table of contents

+ [Video guide](#video-guide)
+ [Install](#install)
  + [Dependencies](#dependencies)
  + [Instructions](#instructions)
    + [Cloning the repository and adjusting the VMaNGOS configuration](#cloning-the-repository-and-adjusting-the-vmangos-configuration)
    + [Adjusting the Docker Compose configuration](#adjusting-the-docker-compose-configuration)
    + [Extracting the client data](#extracting-the-client-data)
    + [Providing the Warden modules (optional)](#providing-the-warden-modules-optional)
    + [Utilizing automatic world database corrections (optional)](#utilizing-automatic-world-database-corrections-optional)
    + [Modifying the world database with custom changes (optional)](#modifying-the-world-database-with-custom-changes-optional)
+ [Usage](#usage)
  + [Starting VMaNGOS](#starting-vmangos)
  + [Observing the VMaNGOS output](#observing-the-vmangos-output)
  + [Creating the first account](#creating-the-first-account)
  + [Stopping VMaNGOS](#stopping-vmangos)
  + [Updating](#updating)
    + [Breaking changes](#breaking-changes)
  + [Creating database backups](#creating-database-backups)
  + [Accessing the database](#accessing-the-database)
  + [Database security](#database-security)
+ [Maintainer](#maintainer)
+ [Contribute](#contribute)
+ [License](#license)

## Video guide

[![Video guide by Digital Scriptorium][youtube-video-guide-thumbnail]][youtube-video-guide]

The YouTube channel [Digital Scriptorium][youtube-digital-scriptorium] has
created a [video guide][youtube-video-guide] that walks you through the
installation and usage of vmangos-deploy. It is intended for Windows users (and
as such also covers some Windows-specific topics like WSL2), but the steps for
setting up vmangos-deploy itself are essentially the same for all operating
systems and thus, the video should also be helpful for Linux and macOS users.

The video covers everything you need to get started with a default setup. It is
still recommended to read through this README as it contains additional
information that may be useful, especially if you want to customize further.

> [!NOTE]
> In case the instructions provided in the video become outdated, it will be
> mentioned here.

## Install

### Dependencies

+ [Docker][docker] (including [Compose V2][docker-compose])

### Instructions

#### Cloning the repository and adjusting the VMaNGOS configuration

First, clone the repository and create copies of the provided VMaNGOS example
configuration files:

```sh
git clone https://github.com/mserajnik/vmangos-deploy.git
cd vmangos-deploy
cp ./config/mangosd.conf.example ./config/mangosd.conf
cp ./config/realmd.conf.example ./config/realmd.conf
```

Next, adjust the two configuration files you have just created for your desired
setup. The default configuration should work well as a starting point, but you
may still want to adjust certain things such as the `GameType`, the `RealmZone`
or `Anticheat.*` and `Warden.*` options. Descriptions are provided for each
option in the configuration files, so you should be able to find your way
around easily.

> [!CAUTION]
> Options relating to certain things that vmangos-deploy relies on to work
> correctly (like the database connections or configured directories such as
> the `DataDir` or the `LogsDir`) should not be adjusted unless you absolutely
> need to change them and are aware of the implications (e.g., which
> other configuration options may need to be adjusted as well to avoid
> discrepancies resulting in unexpected behavior). No support will be provided
> for non-default setups.

### Adjusting the Docker Compose configuration

Once you are done adjusting the VMaNGOS configuration, create a copy of the
Docker Compose example configuration:

```sh
cp ./compose.yaml.example ./compose.yaml
```

Next, adjust your `compose.yaml`. The first thing to decide on is which Docker
images you want to use based on the client version the server should support.
You can choose from the following versions:

| Supported client version | Image                                   |
| ------------------------ | --------------------------------------- |
| `1.12.1.5875`            | `ghcr.io/mserajnik/vmangos-server:5875` |
| `1.11.2.5464`            | `ghcr.io/mserajnik/vmangos-server:5464` |
| `1.10.2.5302`            | `ghcr.io/mserajnik/vmangos-server:5302` |
| `1.9.4.5086`             | `ghcr.io/mserajnik/vmangos-server:5086` |
| `1.8.4.4878`             | `ghcr.io/mserajnik/vmangos-server:4878` |
| `1.7.1.4695`             | `ghcr.io/mserajnik/vmangos-server:4695` |
| `1.6.1.4544`             | `ghcr.io/mserajnik/vmangos-server:4544` |

Adjust the configured image for the `realmd` and `mangosd` services based on
this table. E.g., if you wanted to run a server that supports client version
`1.6.1.4544`, you would choose `ghcr.io/mserajnik/vmangos-server:4544`.

By default, the latest available images are used. Alternatively, you can also
select specific ones via the VMaNGOS commit hash they have been built from. To
allow for this, the `vmangos-server` image (used by the `realmd` and `mangos`
services) and the `vmangos-database` image (used by the `database` service)
have tags that include the respective commit hash. E.g., for commit
[`46183d287f80ab1ebf27bab12f37bc0b5b188c86`][vmangos-example-commit]:

| `realmd`/`mangos` service image                                                  | `database` service image                                                      |
| -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `ghcr.io/mserajnik/vmangos-server:5875-46183d287f80ab1ebf27bab12f37bc0b5b188c86` | `ghcr.io/mserajnik/vmangos-database:46183d287f80ab1ebf27bab12f37bc0b5b188c86` |

> [!IMPORTANT]
> When you decide to select images via VMaNGOS commit hash you should always
> make sure to use the same one for the `vmangos-server` and the
> `vmangos-database` images so there are no potential discrepancies between
> code and data. It is _not_ possible (or intended) to switch to images based
> on an older commit than the previous ones you used to perform a clean
> downgrade due to the database migrations.

Since the Docker images are generally built only once a day it, is unlikely
that there will be a build for every single VMaNGOS commit. Older images are
automatically deleted, roughly after 45 days; in practice, you should not rely
on specific images staying available for any prolonged period of time. If you
absolutely need images based on a specific VMaNGOS commit, you can always build
them yourself instead.

> [!TIP]
> You can find all the currently available `vmangos-server` and
> `vmangos-database` images [here][image-vmangos-server-versions] and
> [here][image-vmangos-database-versions] respectively.

Aside from which Docker images you want to use you mainly have to pay attention
to the `environment` sections of each service configuration. In particular, you
will want to adjust the `TZ` (time zone) environment variable for each service.
The `VMANGOS_REALMLIST_*` environment variables of the `database` service
should also be of interest; changing the `VMANGOS_REALMLIST_ADDRESS` to a LAN
IP, a WAN IP or a domain name is required if you want to allow non-local
connections.

Also take note of the `healthcheck` sections; if you are using a low end system
you may have to adjust the `start_period` setting so that the initial database
creation process will be able to complete in time before the healthcheck
considers the container unhealthy and causes a restart.

> [!CAUTION]
> Anything in your `compose.yaml` that is not commented or explicitly mentioned
> in this README, regardless of the section, is likely something you do not
> have to (or, in some cases, _must not_) change. Doing so may lead to
> unexpected behavior and is not supported.

### Extracting the client data

VMaNGOS uses data that is generated from extracted client data to handle things
like mob movement and line of sight. If you have already acquired this data
previously, you can place it directly into
[`./storage/mangosd/extracted-data`](storage/mangosd/extracted-data) and skip
the next steps.

To extract the data, first copy the contents of your client directory into
[`./storage/mangosd/client-data`](storage/mangosd/client-data). Next, simply
run the following command:

```sh
docker run \
  -i \
  -v ./storage/mangosd/client-data:/opt/vmangos/storage/client-data \
  -v ./storage/mangosd/extracted-data:/opt/vmangos/storage/extracted-data \
  --rm \
  --user 1000:1000 \
  ghcr.io/mserajnik/vmangos-server:5875 \
  extract-client-data
```

There are two things to look out for here:

+ If you are using a Linux host and your user's UID and GID are not 1000,
  change the `--user` argument to reflect your user's UID and GID. This will
  cause the user in the container to use the same UID and GID and prevent
  permission issues on the bind mounts. If you are on Windows or macOS, you can
  ignore this (or even remove the `--user` argument altogether, if you want to)
+ The Docker image must reflect the client version you want to extract the data
  from; see the table further above in the
  [Docker Compose configuration section](#adjusting-the-docker-compose-configuration)

> [!IMPORTANT]
> Extracting the data can take many hours (depending on your hardware). Some
> notices/errors during the process are normal and usually nothing to worry
> about (as long as the execution continues afterwards).

Once the extraction is finished you can find the data in
[`./storage/mangosd/extracted-data`](storage/mangosd/extracted-data). Note that
you may want to re-run the process in the future if VMaNGOS makes changes (to
benefit from potentially improved mob movement etc.). In case it becomes
necessary to do so (e.g., if the extraction process changes), the
[breaking changes section](#breaking-changes) further below will be updated
accordingly.

If you re-run the extraction, it will automatically detect previously extracted
data and ask you if you want to continue (which will overwrite the old data).
You can also skip this confirmation prompt (and force the re-extraction) by
adding the `--force` flag to the `extract-client-data` command, like this:

```sh
docker run \
  -i \
  -v ./storage/mangosd/client-data:/opt/vmangos/storage/client-data \
  -v ./storage/mangosd/extracted-data:/opt/vmangos/storage/extracted-data \
  --rm \
  --user 1000:1000 \
  ghcr.io/mserajnik/vmangos-server:5875 \
  extract-client-data --force
```

### Providing the Warden modules (optional)

To use Warden, you have to provide the [Warden modules][warden-modules]
yourself. See [here][compose-warden-modules] for details on how to do so.

> [!WARNING]
> Using [HermesProxy][hermesproxy] (or projects derived from it) to connect
> `1.14.x` clients to VMaNGOS will likely not be possible (in a stable manner
> without getting kicked off the server) when Warden is enabled.

### Utilizing automatic world database corrections (optional)

vmangos-deploy keeps track of certain, unusual VMaNGOS code changes (such as
migration edits) that lead to a faulty (or out-of-sync) world database state
when updating and would normally require manual intervention by you to rectify.

By default, vmangos-deploy can automatically correct the state of your world
database in such cases by re-creating it. It is strongly suggested to keep this
feature enabled.

If you do decide to [disable it][compose-automatic-world-db-corrections], you
yourself are responsible for monitoring VMaNGOS for problematic code changes
and taking appropriate actions (e.g., manually triggering the re-creation of
the world database by mounting a database dump, as described
[here][compose-world-db-dump-mount]).

### Modifying the world database with custom changes (optional)

If you want to make custom changes to the world database, it is recommended to
do so using SQL files and placing them in
[`./storage/database/custom-sql`](storage/database/custom-sql) (a bind mount
for this directory is
[configured out-of-the-box][compose-custom-sql-bind-mount]). This way, you can
keep
[automatic world database corrections](#utilizing-automatic-world-database-corrections-optional)
enabled without having to worry about your changes getting lost.

By default, all SQL files (files with a `.sql` extension) in that directory
will be processed during each startup in alphabetical order (after the world
database has been created and updated with the latest migrations). Thus, the
SQL statements in your files have to be idempotent (i.e., they can be processed
multiple times without causing issues).

An example SQL file that shows how you can populate the `auctionhousebot` table
with custom data
[is provided](storage/database/custom-sql/auctionhousebot.sql.example). This
SQL file will not be processed by default without removing the `.example`
suffix from the file name. If you want to use it, it is recommended to first
make a copy of the file and then adjust the copy to your liking instead of
renaming the original file (to avoid dirtying the working tree).

You can find further details about this feature [here][compose-custom-sql].

## Usage

### Starting VMaNGOS

Once you are happy with the configuration and have extracted the client data,
you can start VMaNGOS for the first time. To do so, run:

```sh
docker compose up -d
```

This pulls the Docker images first and afterwards automatically creates and
starts the containers. During the first startup it might take a little longer
until the server becomes available due to the initial database creation.

> [!CAUTION]
> Make sure to not (accidentally) stop VMaNGOS before the database creation
> process has finished; otherwise, you will likely end up with a broken
> database and will have to delete and re-create it.

### Observing the VMaNGOS output

Especially during the first startup you might want to follow the server output
to know when VMaNGOS is up and running:

```sh
docker compose logs -f mangosd
```

Once you see the output `World initialized.` you know that the intialization
process has finished and VMaNGOS is ready.

### Creating the first account

To create the first account, attach to the `mangosd` container (make sure
[that the server is ready](#observing-the-vmangos-output) before attaching):

```sh
docker attach vmangos-deploy-mangosd-1
```

After attaching, create the account and assign an account level:

```sh
account create <account name> <account password>
account set gmlevel <account name> <account level> # see https://github.com/vmangos/core/blob/46183d287f80ab1ebf27bab12f37bc0b5b188c86/src/shared/Common.h#L183-L189
```

When you are done, detach from the Docker container by pressing
<kbd>Ctrl</kbd>+<kbd>P</kbd> and <kbd>Ctrl</kbd>+<kbd>Q</kbd>. You should
now be able to log in with your newly created account.

### Stopping VMaNGOS

To stop VMaNGOS, simply run:

```sh
docker compose down
```

### Updating

To update, pull the latest images:

```sh
docker compose pull
```

Afterwards, re-create the containers:

```sh
docker compose up -d
```

> [!NOTE]
> Selecting specific images via VMaNGOS commit hash (as described further
> above) will obviously prevent you from updating until you edit each
> respective service in your `compose.yaml` to pull newer images. Attempting to
> update without changing the configured images is not harmful, it will just
> not have any effect.

#### Breaking changes

It is recommended to regularly check this repository (either manually or by
updating your local repository via `git pull`). Usually, the commits here will
just consist of maintenance and potentially new VMaNGOS configuration options
(that you may want to incorporate into your configuration).

Sometimes, there may be new features or changes that require manual
intervention. Such breaking changes will be listed here (and removed again once
they become irrelevant), sorted by newest first:

+ __[2025-02-22] - Automatic world database corrections are now available and__
  __enabled by default:__ vmangos-deploy now keeps track of certain, unusual
  VMaNGOS code changes (such as migration edits) that lead to a faulty (or
  out-of-sync) world database state when updating and would normally require
  manual intervention by you to rectify. In such cases, vmangos-deploy can
  automatically correct the state of your world database by re-creating it. It
  is strongly suggested to keep this feature enabled. If you do decide to
  [disable it][compose-automatic-world-db-corrections] in your `compose.yaml`,
  you yourself are responsible for monitoring VMaNGOS for problematic code
  changes and taking appropriate actions (e.g., manually triggering the
  re-creation of the world database by mounting a database dump, as described
  [here][compose-world-db-dump-mount]). This section will no longer list such
  changes.
+ __[2024-10-31] - Removal of separate images with anticheat support:__
  As of
  [`vmangos/core@fbbc4ae`](https://github.com/vmangos/core/commit/fbbc4ae899f876a78a37d8fee805dce40a182331)
  VMaNGOS no longer supports building without anticheat support, thus anticheat
  is always available and there is no longer a need for separate images. If
  you were using one of the anticheat images (which were suffixed with
  `-anticheat`), simply switch to the regular version of that image.

### Creating database backups

It is recommended to perform regular database backups, particularly before
updating.

To automatically create database backups periodically, uncomment the
[`database-backup` service configuration][compose-database-backups] in your
`compose.yaml` and follow the comments for further information.

### Accessing the database

To make certain changes (e.g., managing accounts or changing the realm
configuration) it can be necessary to access the database with a MySQL/MariaDB
client.

A common web-based MySQL/MariaDB database administration tool called
[phpMyAdmin][phpymadmin] is included and can be enabled by uncommenting the
[`phpmyadmin` service configuration][compose-phpmyadmin] in your
`compose.yaml`. See the comments there for further information.

### Database security

It is not recommended to expose your database to the public (whether through
direct port access, a WAN-accessible phpMyAdmin instance, or any other means).
If you decide to do so, you will have to implement appropriate security
measures. Please note that no further support or guidance regarding this will
be provided here.

> [!CAUTION]
> The default database users with full access to all VMaNGOS data (`root` and
> the user named via `MARIADB_USER` environment variable) do not have any
> restrictions in place in regards to which IPs/hosts can connect.

## Maintainer

[Michael Serajnik][maintainer]

## Contribute

You are welcome to help out!

[Open an issue][issues] or [make a pull request][pull-requests].

## License

[AGPL-3.0-or-later](LICENSE) © Michael Serajnik

[badge-actions-status]: https://github.com/mserajnik/vmangos-deploy/actions/workflows/build-docker-images.yaml/badge.svg
[badge-actions-status-url]: https://github.com/mserajnik/vmangos-deploy/actions/workflows/build-docker-images.yaml
[badge-latest-build-date]: https://img.shields.io/endpoint?url=https%3A%2F%2Fscripts.mser.at%2Fvmangos-deploy-badges%2Fdate-badge.json
[badge-latest-build-date-url]: https://github.com/mserajnik?tab=packages&repo_name=vmangos-deploy
[badge-latest-vmangos-commit]: https://img.shields.io/endpoint?url=https%3A%2F%2Fscripts.mser.at%2Fvmangos-deploy-badges%2Fcommit-badge.json
[badge-latest-vmangos-commit-url]: https://github.com/vmangos/core/commits/development/

[compose-automatic-world-db-corrections]: https://github.com/mserajnik/vmangos-deploy/blob/master/compose.yaml.example#L52-L63
[compose-custom-sql]: https://github.com/mserajnik/vmangos-deploy/blob/master/compose.yaml.example#L64-L81
[compose-custom-sql-bind-mount]: https://github.com/mserajnik/vmangos-deploy/blob/master/compose.yaml.example#L20
[compose-database-backups]: https://github.com/mserajnik/vmangos-deploy/blob/master/compose.yaml.example#L213-L248
[compose-phpmyadmin]: https://github.com/mserajnik/vmangos-deploy/blob/master/compose.yaml.example#L250-L269
[compose-warden-modules]: https://github.com/mserajnik/vmangos-deploy/blob/master/compose.yaml.example#L197-L207
[compose-world-db-dump-mount]: https://github.com/mserajnik/vmangos-deploy/blob/master/compose.yaml.example#L21-L35
[docker]: https://docs.docker.com/get-docker/
[docker-compose]: https://docs.docker.com/compose/install/
[hermesproxy]: https://github.com/WowLegacyCore/HermesProxy
[image-vmangos-database-versions]: https://github.com/mserajnik/vmangos-deploy/pkgs/container/vmangos-database/versions?filters%5Bversion_type%5D=tagged
[image-vmangos-server-versions]: https://github.com/mserajnik/vmangos-deploy/pkgs/container/vmangos-server/versions?filters%5Bversion_type%5D=tagged
[phpymadmin]: https://www.phpmyadmin.net/
[vmangos]: https://github.com/vmangos/core
[vmangos-example-commit]: https://github.com/vmangos/core/commit/46183d287f80ab1ebf27bab12f37bc0b5b188c86
[warden-modules]: https://github.com/vmangos/warden_modules
[youtube-digital-scriptorium]: https://www.youtube.com/@Digital-Scriptorium
[youtube-video-guide]: https://www.youtube.com/watch?v=XWVvT9lMy28
[youtube-video-guide-thumbnail]: https://img.youtube.com/vi/XWVvT9lMy28/0.jpg

[issues]: https://github.com/mserajnik/vmangos-deploy/issues
[maintainer]: https://github.com/mserajnik
[pull-requests]: https://github.com/mserajnik/vmangos-deploy/pulls
