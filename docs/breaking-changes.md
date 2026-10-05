# Breaking changes

Some updates require you to adjust your configuration. These breaking changes
are listed below, newest first.

Every Docker image checks `VMANGOS_DEPLOY_VERSION` on startup. Each breaking
change raises the number it expects by 1, and thus prevents installations that
lack the necessary adjustments for the breaking change from starting.

To update across a version, first refresh your clone of this repository, as the
[updating your clone section](usage.md#updating-your-clone) describes, so you
have the new example Compose file to compare with.

Then apply every entry up to that version, and set `VMANGOS_DEPLOY_VERSION` to
that number in the `database`, `realmd`, and `mangosd` services.

## Version 1 (2026-10-04)

The relaunch replaced the history of this repository, so `git pull` fails in a
clone from before 2026-10-04. To update such a clone once, run `git fetch` and
then `git reset --hard origin/master` in it. That keeps your `compose.yaml`,
`config/`, and `storage/`, which Git ignores, but discards any edit you made to
the repository's own files. Otherwise, make a new clone of the repository and
move these over without replacing the repository's own files. Either way,
`git pull` works again afterwards.

Version 1 makes many changes to the Compose file, which would be cumbersome to
make by hand. Instead, it is recommended to start from a fresh copy of the
example Compose file, and then re-apply your customizations there. Before you
replace your `compose.yaml` with the fresh copy, note down the changes you made
in it. The database passwords in particular have to stay the same, because an
existing database keeps the passwords it was created with.

Version 1 brings these changes:

- The `realmd` and `mangosd` containers now start as root and switch to the UID
  and GID from `VMANGOS_UID` and `VMANGOS_GID`. Setting `user` instead stops
  the containers with an error.
- The image now sets the database connection of `realmd` and `mangosd`, and
  ignores the `*Database.Info` and `LoginDatabaseInfo` options of the
  configuration files. The servers take the user and password from
  `VMANGOS_DATABASE_USER` and `VMANGOS_DATABASE_PASSWORD`.
- The image also sets `DataDir`, `LogsDir`, `HonorDir`, `Warden.ModuleDir`,
  `WorldServerPort`, `RealmServerPort`, `BindIP`, `Ra.IP`, `Ra.Port`,
  `SOAP.IP`, and `SOAP.Port`, and ignores them in the configuration files.
  `mangosd.conf.example` and `realmd.conf.example` list them in their headers.
  The container ports of `realmd` and `mangosd` are now always the defaults,
  and no longer configurable.
- The example `database` service now has `stop_grace_period: 2m`, so a stop
  during startup lets the running step finish.
- The example `database-backup` service now also backs up the migration edit
  ledger in `maintenance`.
- Every image now checks `VMANGOS_DEPLOY_VERSION` on startup and stops when it
  is missing or different.
- The example Compose file has tool services for the version check and the
  client data extraction, which the [usage documentation](usage.md) describes.

> [!NOTE]
> Changes from before version 1 are superseded, and you do not need to
> incorporate them into your configuration if you start from a fresh copy of
> the example Compose file. If you decide to keep and adjust your old file
> instead, compare it with the new example Compose file to find any other
> changes from before version 1 that you still have to make.
