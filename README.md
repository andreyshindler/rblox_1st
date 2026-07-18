# Rainbow Rush 🌈

A stage-based **obby** (obstacle course) starter game for Roblox, built with
[Rojo](https://rojo.space). The entire obstacle course is generated **in code at
server startup** — no manual Studio building required. Sync, press Play, and you're
running the course.

## Gameplay

- Spawn on the green pad (Stage 0) and parkour across floating rainbow platforms.
- Each platform starts with a glowing **checkpoint** that locks in your progress —
  your `Stage` shows on the leaderboard.
- **Lava strips** in the gaps reset you if you touch them; you respawn at your last
  checkpoint (not the start).
- Reach the gold **finish pad** to score a **Win** and loop back for another lap.
- On-screen HUD shows your current stage and a **Reset to checkpoint** button.

## Project layout

```
default.project.json          # Rojo project — maps folders to Roblox services
src/
  server/
    init.server.luau          # Boots the game (ServerScriptService.Server)
    CourseBuilder.luau        # Procedurally builds the course into Workspace
    CheckpointService.luau    # leaderstats, checkpoints, respawn, lava, finish
  client/
    init.client.luau          # HUD (StarterPlayerScripts.Client)
  shared/
    Config.luau               # Tunables shared by server + client (ReplicatedStorage.Shared)
```

## Running it

1. **Install Rojo** (`cargo install rojo`, `aftman add rojo-rbx/rojo`, or the
   [Studio plugin](https://create.roblox.com/store/asset/13916111004/Rojo)).
2. From the repo root, start the server:
   ```
   rojo serve
   ```
3. In **Roblox Studio**, open a new baseplate, open the **Rojo** plugin, and click
   **Connect**.
4. Press **Play** (F5). The course builds automatically and you spawn at Stage 0.

Prefer a one-shot place file instead of live sync? Build one with:

```
rojo build default.project.json --output RainbowRush.rbxlx
```

then open `RainbowRush.rbxlx` in Studio.

## Tuning

Most knobs live in [`src/shared/Config.luau`](src/shared/Config.luau): number of
stages (`STAGE_COUNT`), platform/gap sizes, spawn height, and colours. Change a value,
re-sync, and the next server build reflects it.
