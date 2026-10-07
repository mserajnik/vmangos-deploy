# Usage

To run VMaNGOS, you choose Docker images for a client version, extract the
client data, and start the server with Docker Compose. Later, you update it to
get the latest VMaNGOS changes. The sections below describe each step, and
other tasks such as creating accounts, making backups, and accessing the
database. The [Docker Compose reference](compose.md) describes each setting in
your `compose.yaml`.

## Choosing images

### Client versions

vmangos-deploy builds one server image per client version that VMaNGOS
supports, all from the same VMaNGOS commit, the tip of the `development`
branch. Set the image of your client version for the `realmd` and `mangosd`
services:

| Client version | Server image                            |
| -------------- | --------------------------------------- |
| `1.12.1.5875`  | `ghcr.io/mserajnik/vmangos-server:5875` |
| `1.11.2.5464`  | `ghcr.io/mserajnik/vmangos-server:5464` |
| `1.10.2.5302`  | `ghcr.io/mserajnik/vmangos-server:5302` |
| `1.9.4.5086`   | `ghcr.io/mserajnik/vmangos-server:5086` |
| `1.8.4.4878`   | `ghcr.io/mserajnik/vmangos-server:4878` |
| `1.7.1.4695`   | `ghcr.io/mserajnik/vmangos-server:4695` |
| `1.6.1.4544`   | `ghcr.io/mserajnik/vmangos-server:4544` |
| `1.5.1.4449`   | `ghcr.io/mserajnik/vmangos-server:4449` |

The `database` service uses `ghcr.io/mserajnik/vmangos-database` for every
client version.

### Pinning a specific VMaNGOS commit

Each image also has a tag with the full VMaNGOS commit it contains, such as
`ghcr.io/mserajnik/vmangos-server:5875-46183d287f80ab1ebf27bab12f37bc0b5b188c86`
and
`ghcr.io/mserajnik/vmangos-database:46183d287f80ab1ebf27bab12f37bc0b5b188c86`.
Use such tags to pin your installation to a specific commit. You have to give
the server and the database image the same commit, so the code and the data
match. The databases apply new migrations on start, so an image older than the
ones you ran before cannot work with them.

Since the Docker images are generally built only once a day, there is likely no
build for every single VMaNGOS commit. Older images are deleted automatically
after 14 days, so do not rely on the registry keeping a specific image after
you first pulled it. If you need images based on a specific VMaNGOS commit, you
can build them yourself. The registry lists the current
[server images][image-vmangos-server-versions] and
[database images][image-vmangos-database-versions].

## Extracting the client data

The server needs data extracted from the game client for handling movement and
line of sight.

Copy the contents of your client directory into `storage/mangosd/client-data/`.
Then, to extract the data, run:

```sh
docker compose run --rm extract-client-data
```

The command runs the image of the `mangosd` service as its user (see the
[`extract-client-data` section](compose.md#extract-client-data)), so the
image's client version has to match the client you extract from.

The extraction writes the data into `storage/mangosd/extracted-data/` and can
take many hours. It prints some notices and errors while it runs that are
normal as long as the command does not end with an error.

If you already have extracted data from another source, put it into
`storage/mangosd/extracted-data/`. You can then skip the extraction.

You may want to extract again when VMaNGOS improves the extractors in some way.
To do so, run the same command. It asks before it overwrites the old data. To
skip the question, add `--force` at the end of the command.

## Anticheat and Warden

VMaNGOS's anticheat checks player movement. By default, it is disabled. The
`Anticheat.*` options in your `config/mangosd.conf` turn it on and adjust it.

To use Warden, download the [Warden modules][warden-modules] into
`storage/mangosd/warden-modules/`, uncomment the mount for that directory in
your `compose.yaml`, and adjust the `Warden.*` options in your
`config/mangosd.conf`.

> [!WARNING]
> Using [HermesProxy][hermesproxy] (or projects derived from it) to connect
> `1.14.x` or other modern Classic clients to VMaNGOS is likely to result in
> disconnects when Warden is enabled.

## Running VMaNGOS

To start VMaNGOS, run:

```sh
docker compose up -d
```

The first start takes longer, because it creates the databases.

> [!WARNING]
> Do not interrupt the first start. If it stops early and the next start of the
> `database` service fails, remove the database volume with
> `docker compose down -v`, and start again.

To follow the server output, run:

```sh
docker compose logs -f mangosd
```

The server is ready when it prints `World initialized.`.

To stop VMaNGOS, run:

```sh
docker compose down
```

## Accounts

To create an account, attach to the server console once the server is ready:

```sh
docker compose attach mangosd
```

Then create the account and give it an account level:

```text
account create <account-name> <password>
account set gmlevel <account-name> <level>
```

| Level | Type          |
| ----- | ------------- |
| `0`   | Player        |
| `1`   | Moderator     |
| `2`   | Ticket Master |
| `3`   | Game Master   |
| `4`   | Basic Admin   |
| `5`   | Developer     |
| `6`   | Administrator |

To leave the console again, press <kbd>Ctrl</kbd>+<kbd>P</kbd> and then
<kbd>Ctrl</kbd>+<kbd>Q</kbd>. You can then log in with the account you created.

> [!NOTE]
> From level `1` up, characters on the account get some Game Master behavior,
> depending on the level. The `GM.*` options in your `config/mangosd.conf`
> adjust some of it. From level `3` up, characters are invulnerable, unless you
> set `GM.CheatGod = 0` to play with such an account.

## Connecting a client

The game client reads the address of the login server from `realmlist.wtf` in
the client directory. To play on the host itself, set it to:

```text
set realmlist 127.0.0.1
```

To connect from another machine, use the host's LAN address, WAN address, or
domain name instead. Set `VMANGOS_REALMLIST_ADDRESS` in your `compose.yaml` to
the same address, because the client receives the address of the world server
from the realm list.

## Updating

To update, pull the new images and check them:

```sh
docker compose pull
docker compose run --rm check-deploy-version
```

When the new images need configuration adjustments due to a
[breaking change](breaking-changes.md), the check fails and names the version
they expect. Make those adjustments first. The `check-deploy-version` service
reads only `VMANGOS_DEPLOY_VERSION` of `mangosd`. The `database`, `realmd`, and
`mangosd` services also each check their own value when they start, so you have
to set the same number in all three.

If the check passes and prints that the variable matches, re-create the
containers:

```sh
docker compose up -d
```

If you pinned your installation to a specific commit, the update only takes
effect once you set newer tags.

On the first start after an update, the `database` service applies the new
migrations to the databases. If a migration fails, the `database` service logs
the error, and its automatic restart counts the migration as applied. The cause
is a bug or something in your installation. Check the log for what failed, and
decide for yourself how to continue. You likely have to restore a backup from
before the update: remove the database volume with `docker compose down -v`,
start again, and restore the backup as the
[restoring a backup section](#restoring-a-backup) shows. With the
`database-backup` service as the Compose file sets it up, the restore loses the
event progress of the world, as the [backups section](#backups) describes.

### Updating your clone

Update your clone of this repository regularly with `git pull`, and always
before you apply a breaking change, so you have the updated example Compose
file to compare with.

> [!IMPORTANT]
> The relaunch replaced the history of this repository, so `git pull` fails in
> a clone from before 2026-10-04. To update such a clone once, run `git fetch`
> and then `git reset --hard origin/master` in it. That keeps your
> `compose.yaml`, `config/`, and `storage/`, which Git ignores, but discards
> any edit you made to the repository's own files. Afterwards, `git pull` works
> again.

Most other changes are maintenance or new VMaNGOS options that you may want in
your configuration.

## Migration edits

Sometimes, upstream edits a migration that your databases have already applied.
The database cannot apply such a change again, so vmangos-deploy detects these
edits and acts on them.

- For the world database, the `database` service re-creates it from the new
  image. It keeps the `variables` table, so hardcoded event progress, such as
  the stage of the AQ War Effort, carries over. Other changes you made directly
  in the world database are lost, such as your own NPCs or `npc_vendor` edits.
  Keep such changes as [custom SQL](#custom-sql), which the database runs again
  after the re-creation.
- A database with player data cannot be re-created. For those, the start halts
  and asks you to apply the change by hand, as the next section describes.

The [`database` section](compose.md#database) of the Docker Compose reference
describes the two variables that control this.

### Applying changes by hand

When the start halts, the `database` service prints the affected databases and
the link to each upstream commit. `realmd` and `mangosd` wait for the database,
so `docker compose up -d` keeps waiting too. Read the message from a second
terminal:

```sh
docker compose logs database
```

The container waits as long as you need. To resolve the halt:

1. Open each linked commit and read its changes to the SQL files.
2. Apply the same changes to each affected database, with the name in
   parentheses in the message. To open a database, run:

   ```sh
   docker compose exec database mariadb -u root -p <database>
   ```

   The password is `MARIADB_ROOT_PASSWORD` from your `compose.yaml`.
3. Once you have applied every change, confirm:

   ```sh
   docker compose exec database vmangos-confirm-changes
   ```

The start then records the commits as applied and continues. To give up on the
start, run `docker compose down`.

> [!WARNING]
> The confirmation marks the listed commits as applied without checking your
> database. If your change is wrong or incomplete, the database stays
> inconsistent, and VMaNGOS may fail to start. Matching what the commits do is
> your responsibility.

## Custom SQL

To make your own changes to the world database, put them into `.sql` files in
`storage/database/custom-sql/`. The `database` service runs every file there in
alphabetical order on every start, after the migrations, and after a
re-creation of the world database too. So the statements have to be idempotent:
running them twice has to give the same result as running them once.

[`auctionhousebot.sql.example`](../storage/database/custom-sql/auctionhousebot.sql.example)
shows how to fill the `auctionhousebot` table. The service skips it because of
its `.example` suffix. To use it, copy it to a name ending in `.sql` and adjust
the copy.

## Backups

Back up the databases regularly, especially before updating. The
`database-backup` service in your `compose.yaml` does it daily once you
uncomment it (see the
[`database-backup` section](compose.md#database-backup-optional)).

> [!IMPORTANT]
> The Compose file leaves the world and logs databases out of the
> `database-backup` service, because most personal installations likely do not
> care enough about their contents to accept much larger backups. Apart from
> changes you make to it yourself, the image can re-create the world database.
> The world database also stores the event progress of the world, such as the
> stage of the AQ War Effort, in its `variables` table. The logs database
> stores what the servers log to it. To back up either, add `mangos` or `logs`
> to `DB_DUMP_INCLUDE`.

To create a backup right away, run:

```sh
docker compose run --rm -e DB_DUMP_CRON= -e DB_DUMP_ONCE=true database-backup
```

The empty `DB_DUMP_CRON` is needed, because the service cannot combine a
schedule with a one-off run.

### Restoring a backup

A restore drops and re-creates the tables of each database in the backup. To
restore one:

1. Stop the servers, which would otherwise read and write the tables while they
   change:

   ```sh
   docker compose stop realmd mangosd
   ```

2. Restore the backup, with its file name from `storage/database/backups/`:

   ```sh
   docker compose run --rm database-backup restore --target /backup \
     <backup-file>
   ```

3. Restart the database, which applies the migrations the backup lacks and
   writes the realm entry again, then start the servers:

   ```sh
   docker compose restart database
   docker compose start realmd mangosd
   ```

   If the backup is older than a migration edit, the restart handles the edit
   again, as the [migration edits section](#migration-edits) describes.

## Database access

Some tasks, such as managing accounts or changing the realm entry, need a
MariaDB client. The `phpmyadmin` service in your `compose.yaml` provides one in
the browser once you uncomment it (see the
[`phpmyadmin` section](compose.md#phpmyadmin-optional)).

### Database security

Do not expose the database to the internet, whether through a port mapping, a
phpMyAdmin instance, or anything else. If you expose it anyway, you are
responsible for securing it. vmangos-deploy does not support such a setup.

> [!CAUTION]
> The `root` user and the user from `MARIADB_USER` have full access to all
> VMaNGOS data, from any address.

[hermesproxy]: https://github.com/WowLegacyCore/HermesProxy
[image-vmangos-database-versions]: https://github.com/mserajnik/vmangos-deploy/pkgs/container/vmangos-database/versions?filters%5Bversion_type%5D=tagged
[image-vmangos-server-versions]: https://github.com/mserajnik/vmangos-deploy/pkgs/container/vmangos-server/versions?filters%5Bversion_type%5D=tagged
[warden-modules]: https://github.com/vmangos/warden_modules
