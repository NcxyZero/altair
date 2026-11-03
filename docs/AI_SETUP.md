---
last_setup_date: never
setup_performed: false
setup_complete: false
setup_scope: none
---

# AI workspace setup

This checklist is for an AI agent beginning or resuming work in this repository.
The metadata above is machine-readable handoff state. `setup_performed: true`
means a setup pass has been recorded; `setup_complete: false` means explicitly
skipped steps still need to be considered in a future full setup.

No setup pass has been recorded yet. Never change the metadata without actually
performing the work.

## Checklist

1. Read `.junie/guidelines.md` and then `.junie/working-context.md`.
2. Inspect `git status --short`. Preserve all unrelated and user-owned changes.
3. Run the repository bootstrap when a full setup is requested:

   ```bash
   bash init.sh
   ```

4. Update dependencies, sourcemaps, and generated types:

   ```bash
   bash update.sh
   ```

   The update script also reapplies tracked fixes from `patches/` to generated
   Wally sources. It stops with an error when an installed package version no
   longer matches its patch, so review and refresh that patch before continuing.

5. Inspect the `GameConfig.game.publicGame` identity fields (`placeId`,
   `universeId`, `groupId`). Treat missing IDs and `0` as unconfigured, not as
   valid Roblox identifiers.
6. Check whether Roblox Studio MCP is connected with a harmless read-only
   request. Do not start Studio, publish, or mutate the DataModel merely to make
   this check pass.
7. If Studio MCP is unavailable, finish every setup step that does not require
   it and report the missing connection in the setup handoff.
8. When an identity is needed and the user did not provide it, present the
   available sources and ask which to use: a nonzero ID from `GameConfig`, IDs
   from the connected Studio experience, or an ID provided manually. Do not
   choose a source silently.
9. If Studio is selected, ask whether the currently open experience is the
   intended target place. With permission, read `game.GameId`, `game.PlaceId`,
   `game.CreatorType`, and `game.CreatorId`. When `game.CreatorType` is `Group`,
   record `game.CreatorId` as the group ID. Never confuse the place, universe,
   creator, and group IDs.
10. Update `last_setup_date`, `setup_performed`, `setup_complete`, and
    `setup_scope` to match what was actually completed. Summarize skipped or
    failed steps without placing secrets in this file.

## Place lifecycle question

When the connected place belongs to a new game, ask whether it is the eventual
public/release place or only a development copy. The recommended release flow is
to turn the established development place into the public place at release,
then duplicate it into a new private development place for subsequent work.
This preserves the place that was tested while keeping later development
separate. Treat this as a recommendation, not authorization to publish or copy
anything.

## Optional setup checks

Depending on the task, a full setup can also verify:

- Git branch, remotes, and dirty-worktree ownership.
- Installed versions from `rokit.toml` or `aftman.toml` and whether required
  executables are on `PATH`.
- Rojo project selection and whether `sourcemap.json` matches newly added source
  files.
- Wally dependency availability without rewriting unrelated lock or package
  state.
- Local formatter, linter, and Luau analyzer availability.
- Required environment-variable names by presence only, never their values.
- Whether the open Studio place matches the expected universe before runtime
  tests or Open Cloud operations.
- Open Cloud key scopes and ownership when monetization work is planned; follow
  `docs/MONETIZATION_OPEN_CLOUD.md`.
- Which checks were intentionally skipped because Studio, credentials, network,
  or user confirmation was unavailable.
