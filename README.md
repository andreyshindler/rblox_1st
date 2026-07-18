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
- **Moving platforms** (metal) slide side to side — time your jump. **Disappearing
  platforms** (ice) fade out a moment after you step on, then return, so keep moving.
- A **live timer** runs from the first checkpoint to the finish, and your **Best**
  time is tracked on the leaderboard.
- Reach the gold **finish pad** to score a **Win** and loop back for another lap.
- HUD shows your stage, live timer and best time, plus **Reset to checkpoint** and
  **Skip Stage** buttons. Skip Stage is gated by a gamepass (see below).

## Project layout

```
default.project.json          # Rojo project — maps folders to Roblox services
src/
  server/
    init.server.luau          # Boots the game (ServerScriptService.Server)
    CourseBuilder.luau        # Procedurally builds the course into Workspace
    HazardService.luau        # Moving (TweenService) + disappearing platforms
    CheckpointService.luau    # leaderstats, checkpoints, respawn, lava, finish
    TimerService.luau         # Run timing + best-time tracking (player attributes)
    GamepassService.luau      # Skip-stage gamepass + Skip button remote
  client/
    init.client.luau          # HUD (StarterPlayerScripts.Client)
  shared/
    Config.luau               # Tunables shared by server + client (ReplicatedStorage.Shared)
```

## Skip-stage gamepass

The **Skip Stage** button asks the server to jump you forward one checkpoint,
gated by a gamepass:

1. In Studio, playtest with `ALLOW_SKIP_IN_STUDIO = true` (default) — the button
   works immediately so you can test.
2. For a live game, create a gamepass on your experience and set its id in
   `src/shared/Config.luau` as `SKIP_STAGE_GAMEPASS_ID`. Owners skip instantly;
   non-owners get the Roblox purchase prompt, and a successful purchase performs
   the skip.

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
stages (`STAGE_COUNT`), platform/gap sizes, spawn height, colours, moving-platform
amplitude/speed, disappear timings, and the skip gamepass id. The mix of static /
moving / disappearing platforms is decided by `Config.platformKind(stage)` — edit that
rule to change the pattern. Change a value, re-sync, and the next server build reflects it.

## Notes

- Best times are tracked per session. To persist them across sessions, save the value
  from `TimerService` to a `DataStore` (or an `OrderedDataStore` for a global
  best-time board) — Studio needs *Enable Studio Access to API Services* for that.
- Moving platforms are anchored and tweened; their checkpoint marker rides along each
  frame so it stays with the platform.
