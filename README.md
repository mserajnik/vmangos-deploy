# vmangos-deploy [![GitHub Actions status][actions-status-badge]][actions-status]

> A Docker setup for VMaNGOS

This is a simplified Docker setup for [VMaNGOS][vmangos] based on my
[previous project][vmangos-docker]. It aims to improve upon its foundation
while providing a much nicer experience for the user.

It features:

+ Prebuilt Docker images for both `x86_64` and `aarch64`, leveraging GitHub
  Actions; you no longer need to spend a lot of time re-compiling VMaNGOS every
  time you want to update. The Docker images have been completely rewritten and
  optimized for size and previously redundant images have been merged into a
  single one
+ The ability to run VMaNGOS configured for any of its supported client
  versions; prebuilt images for all versions ranging from `1.6.1.4544` to
  `1.12.1.5875` are provided
+ A more transparent and easier to follow user experience; due to the prebuilt
  Docker images the number of different commands that need to be run to manage
  the server has been greatly reduced and thus it is no longer necessary to use
  various scripts to install, update and manage VMaNGOS. Instead, you can
  simply use the Docker CLI (or any other tool that is able to manage Docker
  containers)
+ A much tidier repository structure; the server configuration can be found in
  [`./config`](config), everything else that is shared between the server and
  your host system lives inside [`./storage`](storage)

The Docker images are built daily, unless there have been no new commits to
VMaNGOS. Additionally, every Monday, the latest images are rebuilt to ensure
that all included software and dependencies are up-to-date, even if there have
been no updates to VMaNGOS itself.

## Table of contents

+ [Install](#install)
  + [Dependencies](#dependencies)
  + [Instructions](#instructions)
    + [Cloning the repository and adjusting the VMaNGOS configuration](#cloning-the-repository-and-adjusting-the-vmangos-configuration)
    + [Adjusting the Docker Compose configuration](#adjusting-the-docker-compose-configuration)
    + [Extracting the client data](#extracting-the-client-data)
    + [Providing the Warden modules (optional)](#providing-the-warden-modules-optional)
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

## Install

### Dependencies

+ [Docker][docker] (including [Compose V2][docker-compose])

### Instructions

#### Cloning the repository and adjusting the VMaNGOS configuration

First, clone the repository and create copies of the provided example
configuration files:

```sh
git clone https://github.com/mserajnik/vmangos-deploy.git
cd vmangos-deploy
cp ./config/mangosd.conf.example ./config/mangosd.conf
cp ./config/realmd.conf.example ./config/realmd.conf
```

Next, you have to adjust the two configuration files you have just created for
your desired setup. Configuration options relating to the database connection
or directories (such as `DataDir` or `LogsDir`) should not be adjusted unless
you know what you are doing and want/need to change the default setup.

### Adjusting the Docker Compose configuration

Once you are done adjusting the VMaNGOS configuration, create a copy of the
Docker Compose example configuration:

```sh
cp ./compose.yaml.example ./compose.yaml
```

Next, adjust your `compose.yaml`. The first thing to decide on is the Docker
image version you want to use based on the client version the server should
support. You can choose from the following versions:

| Supported client version | Image tag                               |
| ------------------------ | --------------------------------------- |
| `1.12.1.5875`            | `ghcr.io/mserajnik/vmangos-server:5875` |
| `1.11.2.5464`            | `ghcr.io/mserajnik/vmangos-server:5464` |
| `1.10.2.5302`            | `ghcr.io/mserajnik/vmangos-server:5302` |
| `1.9.4.5086`             | `ghcr.io/mserajnik/vmangos-server:5086` |
| `1.8.4.4878`             | `ghcr.io/mserajnik/vmangos-server:4878` |
| `1.7.1.4695`             | `ghcr.io/mserajnik/vmangos-server:4695` |
| `1.6.1.4544`             | `ghcr.io/mserajnik/vmangos-server:4544` |

Adjust the configured `image` for the `realmd` and `mangosd` services based on
this table. E.g., if you want to run a server that supports client version
`1.6.1.4544` you would use `ghcr.io/mserajnik/vmangos-server:4544`.

Instead of using the latest build you can also use a specific VMaNGOS commit.
To allow for this, the `vmangos-database` image is tagged with the commit hash
(e.g., `vmangos-database:e87d583a5e50ad49f12a716fb408b393d3c21103`) and the
`vmangos-server` image tag is suffixed with the commit hash (e.g.,
`vmangos-server:5875-e87d583a5e50ad49f12a716fb408b393d3c21103`) so you can
still select the supported client version.

When you decide to use a specific commit you should always make sure to use the
same one for the `vmangos-server` and the `vmangos-database` images so there
are no potential discrepancies between code and data. Note that it is _not_
possible (or intended) to use this feature to perform a clean downgrade due to
the database migrations.

Since the Docker images are built only once a day it is unlikely that there
will be a build for every single VMaNGOS commit; you can find all the available
versions for the `vmangos-server` and the `vmangos-database` images
[here][image-vmangos-server-versions] and
[here][image-vmangos-database-versions] respectively. Older images are
automatically deleted; only the images from the last 22 builds are kept (which
usually means the builds from the last 22 days, unless there have been builds
outside of the normal daily schedule or there have been no VMaNGOS commits on
some days).

Aside from the Docker image version you mainly have to pay attention to the
`environment` sections of each service configuration. In particular, you will
want to adjust the `TZ` (time zone) environment variable for each service. The
`VMANGOS_REALMLIST_*` environment variables of the `database` service should
also be of interest; changing `VMANGOS_REALMLIST_ADDRESS` to a LAN IP, a WAN IP
or a domain name is required if you want to allow non-local connections.

Also take note of the `healthcheck` sections; if you are on a low end system
you may have to adjust the `start_period` setting so that the initial database
creation process will be able to complete in time before the healthcheck
considers the container unhealthy and causes a restart.

Anything else that is not commented is likely something you do not not have to
(or, in some cases, _must not_) adjust; this applies to everything including
port mappings, volumes and environment variables.

### Extracting the client data

VMaNGOS uses data that is generated from extracted client data to handle things
like movement and line of sight. If you have already acquired this data
previously, you can place it directly into
[`./storage/mangosd/extracted-data`](storage/mangosd/extracted-data) and skip
the next steps.

To generate the data, first copy the contents of your client directory into
[`./storage/mangosd/client-data`](storage/mangosd/client-data). Next, simply
run the following command:

```sh
docker run \
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
  ignore this (and even remove the `--user` argument altogether, if you want
  to)
+ The Docker image version must reflect the client version you want to extract
  the data from; see the table further above in the
  [Docker Compose configuration section](#adjusting-the-docker-compose-configuration)

Generating the data can take many hours (depending on your hardware). Some
notices/errors during the extraction process are normal and nothing to worry
about.

Once the extraction is finished you can find the data in
[`./storage/mangosd/extracted-data`](storage/mangosd/extracted-data). Note that
you may want to re-run the process in the future if VMaNGOS makes changes (to
benefit from potentially improved mob pathing etc.).

### Providing the Warden modules (optional)

Optionally, if want to use Warden you have to provide the
[Warden modules][warden-modules]. See the `volumes` section of the `mangosd`
service in your `compose.yaml` on how to do that.

## Usage

### Starting VMaNGOS

Once you are happy with the configuration and have extracted the client data
you can start VMaNGOS for the first time. To do so, run:

```sh
docker compose up -d
```

This pulls the Docker images first and afterwards automatically creates and
starts the containers. Note that during the first startup it might take a
little longer until the server becomes available due to the initial database
creation. __Make sure to not (accidentally) stop VMaNGOS before the database__
__creation process has finished;__ otherwise, you will likely end up with a
broken database and will have to delete and re-create it.

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
account set gmlevel <account name> <account level> # see https://github.com/vmangos/core/blob/bd9cca7b9d16d3e88c15ed378a893faebaf353f1/src/shared/Common.h#L183-L190
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

Afterwards, recreate the containers:

```sh
docker compose up -d
```

Note that using a specific VMaNGOS commit will obviously prevent you from
updating (but attempting to do so is not harmful, it just will not have any
effect).

#### Breaking changes

It is recommended to regularly check this repository (either manually or by
updating your local repository via `git pull`). Usually, the commits here will
just consist of maintenance and potentially new VMaNGOS configuration options
(that you may want to incorporate into your configuration). Sometimes, there
may be new features or changes that require manual intervention. Such breaking
changes will be listed here (and removed again once they become irrelevant),
sorted by newest first:

+ __[2024-10-31] - Removal of separate images with anticheat support:__
  As of
  [`vmangos/core@fbbc4ae`](https://github.com/vmangos/core/commit/fbbc4ae899f876a78a37d8fee805dce40a182331)
  VMaNGOS no longer supports building without anticheat support, thus anticheat
  is always available and there is no longer a need for separate images. If
  you were using one of the anticheat images (which were suffixed with
  `-anticheat`), simply switch to the regular version of that image.
+ __[2024-10-29] - Migration edits in__
  __[`vmangos/core@e3f0547`](https://github.com/vmangos/core/commit/e3f0547b9973cbb72e250f04362ebf35db388939)__
  __and__
  __[`vmangos/core@ebf9cd8`](https://github.com/vmangos/core/commit/ebf9cd81f88de62dd85f8f127ed91cf7e690da3d):__
  if you have already run the affected migrations before they have been edited
  in these commits, you will have to either manually edit your database to
  reflect these changes or alternatively re-create the world database and run
  migrations again. To do the latter, you can simply mount the initial database
  dump as described [here][world-db-dump-mount]. Make sure your Docker images
  are newer than the commits mentioned above before re-creating the database
  via this method.
+ __[2024-09-25] - Migration edits in__
  __[`vmangos/core@4bad448`](https://github.com/vmangos/core/commit/4bad44863a1d079b62d79e4afc22da49b56cce80)__
  __and__
  __[`vmangos/core@8ab4fbf`](https://github.com/vmangos/core/commit/8ab4fbf3b2df90d84c8a98905da3371a1418ff47):__
  if you have already run the affected migrations before they have been edited
  in these commits, you will have to either manually edit your database to
  reflect these changes or alternatively re-create the world database and run
  migrations again. To do the latter, you can simply mount the initial database
  dump as described [here][world-db-dump-mount]. Make sure your Docker images
  are newer than the commits mentioned above before re-creating the database
  via this method.

### Creating database backups

It is recommended to perform regular database backups, particularly before
updating.

To automatically create database backups periodically, uncomment the
`database-backup` service configuration in your `compose.yaml` and follow the
comments there for further information.

### Accessing the database

To make certain changes (e.g., managing accounts or changing the realm
configuration) it can be necessary to access the database with a MySQL/MariaDB
client.

A common web-based MySQL/MariaDB database administration tool called
[phpMyAdmin][phpymadmin] is included and can be enabled by uncommenting the
`phpmyadmin` service configuration in your `compose.yaml`. See the comments
there for further information.

### Database security

The default database users with full access to all VMaNGOS data (`root` and the
user named via `MARIADB_USER` environment variable) do not have any
restrictions in place in regards to which IPs/hosts can connect. Therefore, you
should __never__ expose your database to the public (whether through direct
port access, a WAN-accessible phpMyAdmin instance, or any other means). If you
decide to do so, you will have to implement appropriate security measures.
Please note that no further support or guidance regarding this will be provided
here.

## Maintainer

[Michael Serajnik][maintainer]

## Contribute

You are welcome to help out!

[Open an issue][issues] or [make a pull request][pull-requests].

## License

[AGPL-3.0-or-later](LICENSE) © Michael Serajnik

[docker]: https://docs.docker.com/get-docker/
[docker-compose]: https://docs.docker.com/compose/install/
[image-vmangos-database-versions]: https://github.com/mserajnik/vmangos-deploy/pkgs/container/vmangos-database/versions?filters%5Bversion_type%5D=tagged
[image-vmangos-server-versions]: https://github.com/mserajnik/vmangos-deploy/pkgs/container/vmangos-server/versions?filters%5Bversion_type%5D=tagged
[phpymadmin]: https://www.phpmyadmin.net/
[vmangos]: https://github.com/vmangos/core
[vmangos-docker]: https://github.com/mserajnik/vmangos-docker
[warden-modules]: https://github.com/vmangos/warden_modules
[world-db-dump-mount]: https://github.com/mserajnik/vmangos-deploy/blob/master/compose.yaml.example#L20-L34

[actions-status]: https://github.com/mserajnik/vmangos-deploy/actions
[actions-status-badge]: https://github.com/mserajnik/vmangos-deploy/actions/workflows/build-docker-images.yaml/badge.svg
[issues]: https://github.com/mserajnik/vmangos-deploy/issues
[maintainer]: https://github.com/mserajnik
[pull-requests]: https://github.com/mserajnik/vmangos-deploy/pulls
