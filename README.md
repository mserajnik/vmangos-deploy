<h1>
  <img src=".github/logo.webp" alt="" height="100">
  <br>
  vmangos-deploy
</h1>

[![Lint status][badge-lint-status]][badge-lint-status-url]
[![Build status][badge-build-status]][badge-build-status-url]\
[![Latest VMaNGOS build][badge-latest-vmangos-build]][badge-latest-vmangos-build-url]
[![Latest build date][badge-latest-build-date]][badge-latest-build-date-url]

> A Docker setup for VMaNGOS

> [!TIP]
> Also check out my new project [cmangos-deploy][cmangos-deploy]: a similar
> Docker setup for [CMaNGOS][cmangos], a server emulator that supports Classic,
> TBC and WotLK.

vmangos-deploy is a Docker-based solution for running [VMaNGOS][vmangos] that
focuses on providing a streamlined and user-friendly experience. It offers a
range of features that simplify managing a VMaNGOS setup:

- __Prebuilt Docker images for both `amd64` and `arm64`, leveraging GitHub__
  __Actions:__ simply pull the provided images that have been optimized for
  size, performance and stability instead of having to re-compile VMaNGOS
  yourself every time you want to update.
- __The ability to run VMaNGOS configured for any of its supported client__
  __versions:__ prebuilt images for all versions ranging from `1.5.1.4449` to
  `1.12.1.5875` are provided.
- __Seamless, automated database migrations:__ when pulling the latest Docker
  images and re-creating the containers, migrations are applied automatically
  to keep your database up to date at all times.
- __A transparent and easy-to-follow user experience:__ the number of different
  commands that need to be run to install and manage VMaNGOS is kept to a
  minimum. You can use the Docker CLI or any other tool that is able to manage
  Docker containers.
- __A clean and organized structure:__ the VMaNGOS configuration can be found
  in [`./config`](config), everything else that is shared between the Docker
  containers and your host system lives inside [`./storage`](storage).

> [!NOTE]
> The Docker images are built on a daily schedule, unless there have been no
> new commits to VMaNGOS since the last build. Additionally, every Monday, the
> latest images are rebuilt to ensure software and dependencies are up to date,
> even if there have been no updates to VMaNGOS itself.

## Table of contents

- [Install](#install)
  - [Dependencies](#dependencies)
  - [Using a coding agent](#using-a-coding-agent)
  - [Instructions](#instructions)
    - [Cloning the repository and adjusting the VMaNGOS configuration](#cloning-the-repository-and-adjusting-the-vmangos-configuration)
    - [Adjusting the Docker Compose configuration](#adjusting-the-docker-compose-configuration)
    - [Extracting the client data](#extracting-the-client-data)
    - [Providing the Warden modules (optional)](#providing-the-warden-modules-optional)
    - [Modifying the world database with custom changes (optional)](#modifying-the-world-database-with-custom-changes-optional)
- [Usage](#usage)
  - [Starting VMaNGOS](#starting-vmangos)
  - [Observing the VMaNGOS output](#observing-the-vmangos-output)
  - [Creating the first account](#creating-the-first-account)
  - [Stopping VMaNGOS](#stopping-vmangos)
  - [Updating](#updating)
    - [What happens during an update](#what-happens-during-an-update)
    - [When vmangos-deploy asks you to apply changes manually](#when-vmangos-deploy-asks-you-to-apply-changes-manually)
    - [Breaking changes](#breaking-changes)
  - [Creating database backups](#creating-database-backups)
  - [Accessing the database](#accessing-the-database)
  - [Database security](#database-security)
- [Maintainer](#maintainer)
- [Contribute](#contribute)
- [Licenses](#licenses)
- [Disclaimer](#disclaimer)

## Install

### Dependencies

- [Docker][docker] (including [Compose V2][docker-compose])

### Using a coding agent

If you have a coding agent like [Claude Code][claude-code] or [Codex][codex]
installed, you can try a prompt similar to the following one to have it assist
you with the installation process:

```
Help me install and set up https://github.com/mserajnik/vmangos-deploy.
First, clone the repository and read the README carefully.
Then guide me through the installation process step by step, following the
README closely.
Do as much of the setup yourself as you safely can so that I only have to step
in when a manual action or personal preference is required.
Ask me about my preferences whenever a choice has to be made, explain the
relevant options clearly, and tailor your instructions to the OS I am using.
Assume that I am not familiar with VMaNGOS or Docker and that I have not read
the README myself.
For steps that I need to perform manually, give me clear instructions and exact
commands where appropriate.
Do not assume user-facing choices such as the client version, optional
services, or networking-related preferences. Ask me whenever the README
presents a meaningful choice.
For settings that the README, the Docker Compose configuration, or the VMaNGOS
example configuration files indicate should generally be left alone, keep the
documented defaults unless I explicitly ask for something else.
Do not change settings that the README, the Docker Compose configuration, or
the VMaNGOS example configuration files indicate should not be changed.
```

The exact prompt that works best may vary depending on the coding agent and
model you use.

> [!CAUTION]
> You use coding agents at your own risk. You are responsible for the
> permissions and access you give them. The maintainer of this project is not
> liable for any damage or data loss resulting from their use. Take appropriate
> precautions such as sandboxed access and limited permissions, and do not run
> them with `--yolo` or similar options that bypass safety checks.

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
> need to change them and are aware of the implications (e.g., which other
> configuration options may need to be adjusted as well to avoid discrepancies
> resulting in unexpected behavior). No support will be provided for
> non-default setups.

#### Adjusting the Docker Compose configuration

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
| `1.5.1.4449`             | `ghcr.io/mserajnik/vmangos-server:4449` |

Adjust the configured image for the `realmd` and `mangosd` services based on
this table. E.g., if you wanted to run a server that supports client version
`1.5.1.4449`, you would choose `ghcr.io/mserajnik/vmangos-server:4449`.

By default, the latest available images are used. Alternatively, you can also
select specific ones via the VMaNGOS commit hash they have been built from. To
allow for this, the `vmangos-server` image (used by the `realmd` and `mangos`
services) and the `vmangos-database` image (used by the `database` service)
have tags that include the respective commit hash. E.g., for commit
[`46183d287f80ab1ebf27bab12f37bc0b5b188c86`][vmangos-example-commit]:

| `realmd` / `mangosd` service image                                               | `database` service image                                                      |
| -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `ghcr.io/mserajnik/vmangos-server:5875-46183d287f80ab1ebf27bab12f37bc0b5b188c86` | `ghcr.io/mserajnik/vmangos-database:46183d287f80ab1ebf27bab12f37bc0b5b188c86` |

> [!IMPORTANT]
> When you decide to select images via VMaNGOS commit hash you should always
> make sure to use the same one for the `vmangos-server` and the
> `vmangos-database` images so there are no potential discrepancies between
> code and data. It is _not_ possible (or intended) to switch to images based
> on an older commit than the previous ones you used to perform a clean
> downgrade due to the database migrations.

Since the Docker images are generally built only once a day, it is unlikely
that there will be a build for every single VMaNGOS commit. Older images are
automatically deleted after 14 days; in practice, you should not rely on
specific images staying available beyond the point in time when you originally
pulled them. If you absolutely need images based on a specific VMaNGOS commit,
you can always build them yourself instead.

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

> [!CAUTION]
> Anything in your `compose.yaml` that is not commented or explicitly mentioned
> in this README, regardless of the section, is likely something you do not
> have to (or, in some cases, _must not_) change. Doing so may lead to
> unexpected behavior and is not supported.

#### Extracting the client data

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

- If you are using a Linux host and your user's UID and GID are not 1000,
  change the `--user` argument to reflect your user's UID and GID. This will
  cause the user in the container to use the same UID and GID and prevent
  permission issues on the bind mounts. If you are on Windows or macOS, you can
  ignore this (or even remove the `--user` argument altogether, if you want
  to).
- The Docker image must reflect the client version you want to extract the data
  from; see the table further above in the
  _[Adjusting the Docker Compose configuration](#adjusting-the-docker-compose-configuration)_
  section.

> [!IMPORTANT]
> Extracting the data can take many hours (depending on your hardware). Some
> notices/errors during the process are normal and usually nothing to worry
> about (as long as the execution continues afterwards).

Once the extraction is finished you can find the data in
[`./storage/mangosd/extracted-data`](storage/mangosd/extracted-data). Note that
you may want to re-run the process in the future if VMaNGOS makes changes (to
benefit from potentially improved mob movement etc.). In case it becomes
necessary to do so (e.g., if the extraction process changes), the
_[Breaking changes](#breaking-changes)_ section further below will be updated
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

#### Providing the Warden modules (optional)

To use Warden, you have to provide the [Warden modules][warden-modules]
yourself. See [here][compose-warden-modules] for details on how to do so.

> [!WARNING]
> Using [HermesProxy][hermesproxy] (or projects derived from it) to connect
> `1.14.x` clients to VMaNGOS will likely not be possible (in a stable manner
> without getting kicked off the server) when Warden is enabled.

#### Modifying the world database with custom changes (optional)

If you want to make custom changes to the world database, it is recommended to
do so using SQL files and placing them in
[`./storage/database/custom-sql`](storage/database/custom-sql) (a bind mount
for this directory is
[configured out-of-the-box][compose-custom-sql-bind-mount]). The files in this
directory are processed on every startup, including after vmangos-deploy
re-creates the world database to apply an upstream migration edit (see the
_[What happens during an update](#what-happens-during-an-update)_ section), so
your changes survive that flow without manual intervention.

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

Once you see the output `World initialized.` you know that the initialization
process has finished and VMaNGOS is ready.

### Creating the first account

To create the first account, attach to the `mangosd` container (make sure
[that the server is ready](#observing-the-vmangos-output) before attaching):

```sh
docker compose attach mangosd
```

After attaching, create the account and assign an account level:

```sh
account create <account-name> <account-password>
account set gmlevel <account-name> <account-level>
```

The available account levels are:

| Level | Type          |
| ----- | ------------- |
| `0`   | Player        |
| `1`   | Moderator     |
| `2`   | Ticket Master |
| `3`   | Game Master   |
| `4`   | Basic Admin   |
| `5`   | Developer     |
| `6`   | Administrator |

E.g., to create an administrator account, set the account level to `6`.

> [!NOTE]
> Setting an account level of `1` or higher means that some Game
> Master-specific behavior will begin to apply to characters on that account.
> Exactly which behavior applies depends on the account level; you can modify
> some of this via the [`GM.*` options][mangosd-gm-options] in your
> `mangosd.conf`.\
> In particular, if you use an account level of `3` or higher, you will
> probably want to set [`GM.CheatGod = 0`][mangosd-gm-options-cheat-god] if you
> intend to actually play normally with the account, because otherwise your
> characters will be invulnerable.

When you are done, detach from the Docker container by pressing
<kbd>Ctrl</kbd>+<kbd>P</kbd> and <kbd>Ctrl</kbd>+<kbd>Q</kbd>. You should now
be able to log in to the game client with your newly created account.

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

#### What happens during an update

vmangos-deploy detects upstream VMaNGOS commits that edit already released
migration files. Such changes would otherwise leave your databases in an
inconsistent state and require manual intervention to rectify.

By default, vmangos-deploy will
[automatically re-create your world database][compose-automatic-world-db-corrections]
when a relevant change is detected. Hardcoded event progress (such as the AQ
War Effort stage) survives the re-creation; everything else in the world
database (your custom NPCs and gameobjects, `npc_vendor` edits, etc.) does not,
so restore those from a backup if you need them back (or use
[custom SQL](#modifying-the-world-database-with-custom-changes-optional) to
cleanly preserve the additions/changes).

For the other databases that contain user state, vmangos-deploy cannot safely
re-create them and instead [halts startup][compose-halt-on-edits] until you
intervene; see the next section.

#### When vmangos-deploy asks you to apply changes manually

When a migration edit is detected that affects a database containing user state
(or a world database edit with automatic corrections disabled), vmangos-deploy
halts startup and prints a message naming the affected database(s) and the
GitHub link(s) to the upstream commit(s).

The container stays running while paused; nothing restarts on its own. To
resolve:

1. Open each linked commit on GitHub and read the changes to
   `sql/migrations/*.sql`.
2. Apply the equivalent SQL to the running database. From the host:
   ```sh
   docker compose exec database mariadb -u root -p <database>
   ```
   where `<database>` is `characters`, `realmd`, `logs`, or `mangos`. `mariadb`
   will prompt for the password; it matches your `MARIADB_ROOT_PASSWORD`
   setting in `compose.yaml`.
3. When you are done, confirm by running on the host:
   ```sh
   docker compose exec database vmangos-confirm-changes
   ```

vmangos-deploy will then record the acknowledgement and continue startup. If
you instead want to abort, run `docker compose down`.

> [!CAUTION]
> When you run `vmangos-confirm-changes`, vmangos-deploy treats the listed
> commits as applied and continues. It does not check your database to verify
> that the changes you made match what the commits describe. If your manual fix
> is incorrect or incomplete, the database will be in an inconsistent state and
> VMaNGOS may fail to start. The responsibility for matching what the commits
> do is yours; vmangos-deploy provides no further support for resolving these
> issues.

#### Breaking changes

It is recommended to regularly check this repository (either manually or by
updating your local repository via `git pull`). Usually, the commits here will
just consist of maintenance and potentially new VMaNGOS configuration options
(that you may want to incorporate into your configuration).

Sometimes, there may be new features or changes that require manual
intervention. Such breaking changes will be listed here (and removed again once
they become irrelevant), sorted by newest first:

- __[2026-05-11] - Several changes to the database and server service__
  __configurations are required:__ vmangos-deploy now also detects migration
  edits affecting databases that contain user state (in addition to the world
  database) and halts startup until you apply the equivalent SQL by hand; see
  the
  _[When vmangos-deploy asks you to apply changes manually](#when-vmangos-deploy-asks-you-to-apply-changes-manually)_
  section. To opt out of halting (vmangos-deploy will instead log a warning on
  every start until you take action), set
  [`VMANGOS_HALT_ON_MIGRATION_EDITS=0`][compose-halt-on-edits] in your
  `compose.yaml`. The `database` service's healthcheck must also be updated to
  use the bundled `vmangos-healthcheck` wrapper, and the `realmd` and `mangosd`
  services need to wait for the `service_healthy` state of the `database`
  service instead of waiting for the TCP port (`WAIT_HOSTS` and `WAIT_TIMEOUT`
  are deprecated; after 2026-08-31, vmangos-deploy will fail to start if these
  are still set). See the
  [updated example Compose configuration](compose.yaml.example) for the exact
  configuration. Additionally, the bind mount escape hatch that re-created the
  world database from a file at `/sql/world-new.sql` is removed; there is no
  direct replacement. On first startup with the new image, existing
  installations will see exactly one world database re-creation (or halt) to
  apply the most recent flagged migration edit.
- __[2024-10-31] - Removal of separate images with anticheat support:__ As of
  [`vmangos/core@fbbc4ae`](https://github.com/vmangos/core/commit/fbbc4ae899f876a78a37d8fee805dce40a182331)
  VMaNGOS no longer supports building without anticheat support, thus anticheat
  is always available and there is no longer a need for separate images. If you
  were using one of the anticheat images (which were suffixed with
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
[phpMyAdmin][phpmyadmin] is included and can be enabled by uncommenting the
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
> the user named via the `MARIADB_USER` environment variable) do not have any
> restrictions in place in regards to which IPs/hosts can connect.

## Maintainer

[Michael Serajnik][maintainer]

## Contribute

You are welcome to help out!

[Open an issue][issues] or [make a pull request][pull-requests].

## Licenses

- [`AGPL-3.0-or-later`][license-agpl-3.0-or-later] (Code)
- [`CC-BY-SA-4.0`][license-cc-by-sa-4.0] (Documentation and graphic assets)
- [`CC0-1.0`][license-cc0-1.0] (Configuration files)

This project follows the [REUSE specification][reuse-spec].

## Disclaimer

vmangos-deploy is an independent, community-made Docker setup for the
open-source [VMaNGOS][vmangos] project. It is not affiliated with, endorsed by,
or sponsored by Blizzard Entertainment, Inc., and it is not an official VMaNGOS
project.

This project includes no game client data or other copyrighted game assets. You
must supply your own legitimate game client, from which the required data is
extracted locally on your own machine. It is intended for private,
non-commercial use only and comes with no warranty.

[badge-build-status]: https://github.com/mserajnik/vmangos-deploy/actions/workflows/build-docker-images.yaml/badge.svg
[badge-build-status-url]: https://github.com/mserajnik/vmangos-deploy/actions/workflows/build-docker-images.yaml
[badge-latest-build-date]: https://img.shields.io/endpoint?url=https%3A%2F%2Fscripts.mser.at%2Fvmangos-deploy-badges%2Fdate-badge.json
[badge-latest-build-date-url]: https://github.com/mserajnik?tab=packages&repo_name=vmangos-deploy
[badge-latest-vmangos-build]: https://img.shields.io/endpoint?url=https%3A%2F%2Fscripts.mser.at%2Fvmangos-deploy-badges%2Fbuild-badge.json
[badge-latest-vmangos-build-url]: https://scripts.mser.at/vmangos-deploy-latest-build/
[badge-lint-status]: https://github.com/mserajnik/vmangos-deploy/actions/workflows/lint.yaml/badge.svg
[badge-lint-status-url]: https://github.com/mserajnik/vmangos-deploy/actions/workflows/lint.yaml
[claude-code]: https://www.anthropic.com/product/claude-code
[cmangos]: https://github.com/cmangos
[cmangos-deploy]: https://github.com/mserajnik/cmangos-deploy
[codex]: https://openai.com/codex
[compose-automatic-world-db-corrections]: https://github.com/mserajnik/vmangos-deploy/blob/master/compose.yaml.example#L35-L48
[compose-custom-sql]: https://github.com/mserajnik/vmangos-deploy/blob/master/compose.yaml.example#L62-L79
[compose-custom-sql-bind-mount]: https://github.com/mserajnik/vmangos-deploy/blob/master/compose.yaml.example#L17
[compose-database-backups]: https://github.com/mserajnik/vmangos-deploy/blob/master/compose.yaml.example#L175-L211
[compose-phpmyadmin]: https://github.com/mserajnik/vmangos-deploy/blob/master/compose.yaml.example#L213-L233
[compose-halt-on-edits]: https://github.com/mserajnik/vmangos-deploy/blob/master/compose.yaml.example#L49-L61
[compose-warden-modules]: https://github.com/mserajnik/vmangos-deploy/blob/master/compose.yaml.example#L161-L171
[docker]: https://docs.docker.com/get-docker/
[docker-compose]: https://docs.docker.com/compose/install/
[hermesproxy]: https://github.com/WowLegacyCore/HermesProxy
[image-vmangos-database-versions]: https://github.com/mserajnik/vmangos-deploy/pkgs/container/vmangos-database/versions?filters%5Bversion_type%5D=tagged
[image-vmangos-server-versions]: https://github.com/mserajnik/vmangos-deploy/pkgs/container/vmangos-server/versions?filters%5Bversion_type%5D=tagged
[issues]: https://github.com/mserajnik/vmangos-deploy/issues
[license-agpl-3.0-or-later]: LICENSES/AGPL-3.0-or-later.txt
[license-cc-by-sa-4.0]: LICENSES/CC-BY-SA-4.0.txt
[license-cc0-1.0]: LICENSES/CC0-1.0.txt
[maintainer]: https://github.com/mserajnik
[mangosd-gm-options]: https://github.com/mserajnik/vmangos-deploy/blob/master/config/mangosd.conf.example#L2256-L2361
[mangosd-gm-options-cheat-god]: https://github.com/mserajnik/vmangos-deploy/blob/master/config/mangosd.conf.example#L2361
[phpmyadmin]: https://www.phpmyadmin.net/
[pull-requests]: https://github.com/mserajnik/vmangos-deploy/pulls
[reuse-spec]: https://reuse.software/spec/
[vmangos]: https://github.com/vmangos/core
[vmangos-example-commit]: https://github.com/vmangos/core/commit/46183d287f80ab1ebf27bab12f37bc0b5b188c86
[warden-modules]: https://github.com/vmangos/warden_modules
