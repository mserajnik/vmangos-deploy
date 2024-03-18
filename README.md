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
  versions (with or without anticheat support); prebuilt images for all
  versions ranging from `1.2.4.4222` to `1.12.1.5875` are provided
+ A more transparent and easier to follow user experience; due to the prebuilt
  Docker images the number of different commands that need to be run to manage
  the server has been greatly reduced and thus it is no longer necessary to use
  various scripts to install, update and manage VMaNGOS. Instead, you can
  simply use the Docker CLI (or any other tool that is able to manage Docker
  containers)
+ A much tidier repository structure; the server configuration can be found in
  [`./config`](config), everything else that is shared between the server and
  your host system lives inside [`./storage`](storage)

The Docker images are automatically built every day (unless there have been no
new commits to VMaNGOS).

## Table of contents

+ [Install](#install)
  + [Dependencies](#dependencies)
  + [Instructions](#instructions)
    + [Cloning the repository and adjusting the VMaNGOS configuration](#cloning-the-repository-and-adjusting-the-vmangos-configuration)
    + [Adjusting the Docker Compose configuration](#adjusting-the-docker-compose-configuration)
    + [Extracting the client data](#extracting-the-client-data)
+ [Usage](#usage)
  + [Starting VMaNGOS](#starting-vmangos)
  + [Observing the VMaNGOS output](#observing-the-vmangos-output)
  + [Creating the first account](#creating-the-first-account)
  + [Stopping VMaNGOS](#stopping-vmangos)
  + [Updating](#updating)
  + [Creating database backups](#creating-database-backups)
  + [Accessing the database](#accessing-the-database)
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

Next, adjust your `./compose.yaml`. The first thing to decide on is the Docker
image version you want to use based on the client version the server should
support. You can choose from the following versions:

| Supported client version | Image tags                                                                                 |
| ------------------------ | ------------------------------------------------------------------------------------------ |
| `1.12.1.5875`            | `ghcr.io/mserajnik/vmangos-server:5875`, `ghcr.io/mserajnik/vmangos-server:5875-anticheat` |
| `1.11.2.5464`            | `ghcr.io/mserajnik/vmangos-server:5464`, `ghcr.io/mserajnik/vmangos-server:5464-anticheat` |
| `1.10.2.5302`            | `ghcr.io/mserajnik/vmangos-server:5302`, `ghcr.io/mserajnik/vmangos-server:5302-anticheat` |
| `1.9.4.5086`             | `ghcr.io/mserajnik/vmangos-server:5086`, `ghcr.io/mserajnik/vmangos-server:5086-anticheat` |
| `1.8.4.4878`             | `ghcr.io/mserajnik/vmangos-server:4878`, `ghcr.io/mserajnik/vmangos-server:4878-anticheat` |
| `1.7.1.4695`             | `ghcr.io/mserajnik/vmangos-server:4695`, `ghcr.io/mserajnik/vmangos-server:4695-anticheat` |
| `1.6.1.4544`             | `ghcr.io/mserajnik/vmangos-server:4544`, `ghcr.io/mserajnik/vmangos-server:4544-anticheat` |
| `1.5.1.4449`             | `ghcr.io/mserajnik/vmangos-server:4449`, `ghcr.io/mserajnik/vmangos-server:4449-anticheat` |
| `1.4.2.4375`             | `ghcr.io/mserajnik/vmangos-server:4375`, `ghcr.io/mserajnik/vmangos-server:4375-anticheat` |
| `1.3.1.4297`             | `ghcr.io/mserajnik/vmangos-server:4297`, `ghcr.io/mserajnik/vmangos-server:4297-anticheat` |
| `1.2.4.4222`             | `ghcr.io/mserajnik/vmangos-server:4222`, `ghcr.io/mserajnik/vmangos-server:4222-anticheat` |

Adjust the configured `image` for the `realmd` and `mangosd` services based on
this table. E.g., if you want to run a server that supports client version
`1.6.1.4544` you would use `ghcr.io/mserajnik/vmangos-server:4544`. In
addition, if you want to enable the movement anticheat and/or Warden, choose an
image suffixed with `-anticheat` (such as
`ghcr.io/mserajnik/vmangos-server:4544-anticheat`). If want to use Warden you
will also have to provide the [Warden modules][warden-modules]. See the
`volumes` section of the `mangosd` service in your `./compose.yaml` on how to
do that. Note that the Warden modules are only available for `x86_64`, so you
will not be able to use Warden when using `aarch64` images.

Instead of using the latest build you can also use a specific VMaNGOS commit.
To allow for this, the `vmangos-database` image is tagged with the commit hash
(e.g., `vmangos-database:e87d583a5e50ad49f12a716fb408b393d3c21103`) and the
`vmangos-server` image tag is suffixed with the commit hash (e.g., `vmangos-server:5875-e87d583a5e50ad49f12a716fb408b393d3c21103` or
`vmangos-server:5875-anticheat-e87d583a5e50ad49f12a716fb408b393d3c21103`) so
you can still select the supported client version and choose whether you want
anticheat support or not.

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
automatically deleted; only the images from the last 14 builds are kept (which
usually means the builds from the last 14 days, unless there have been builds
outside of the normal daily schedule or there have been no VMaNGOS commits on
some days).

Aside from the Docker image version you mainly have to pay attention to the
`environment` sections of each service configuration. In particular, you will
want to adjust the `TZ` (time zone) environment parameter for each service. The
`VMANGOS_REALMLIST_*` environment parameters of the `database` service should
also be of interest; changing `VMANGOS_REALMLIST_ADDRESS` to a LAN IP, a WAN IP
or a domain name is required if you want to allow non-local connections.

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

## Usage

### Starting VMaNGOS

Once you are happy with the configuration and have extracted the client data
you can start VMaNGOS for the first time. To do so, run:

```sh
docker compose up -d
```

This pulls the Docker images first and afterwards automatically creates and
starts the containers. Note that during the first startup it might take a
little longer until the server becomes available due to the database creation.

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

It is also recommended to regularly check this repository (either manually or
by updating your local repository via `git pull`). Usually, the commits here
will just consist of maintenance and potentially new VMaNGOS configuration
options (that you may want to incorporate into your configuration). Sometimes,
there may be new features or changes that require manual intervention. While
there should never be anything that breaks your setup, changes in VMaNGOS may
require new bind mounts or other things.

### Creating database backups

It is recommended to perform regular database backups, particularly before
updating.

To automatically create database backups periodically, uncomment the
`database-backup` service configuration in your `./compose.yaml` and follow the
comments there for further information.

### Accessing the database

To make certain changes (e.g., managing accounts or changing the realm
configuration) it can be necessary to access the database with a MySQL/MariaDB
client.

A common web-based MySQL/MariaDB database administration tool called
[phpMyAdmin][phpymadmin] is included and can be enabled by uncommenting the
`phpmyadmin` service configuration in your `./compose.yaml`. See the comments
there for further information.

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

[actions-status]: https://github.com/mserajnik/vmangos-deploy/actions
[actions-status-badge]: https://github.com/mserajnik/vmangos-deploy/actions/workflows/build-docker-images.yaml/badge.svg
[issues]: https://github.com/mserajnik/vmangos-deploy/issues
[maintainer]: https://github.com/mserajnik
[pull-requests]: https://github.com/mserajnik/vmangos-deploy/pulls
