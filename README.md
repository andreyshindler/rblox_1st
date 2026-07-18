# Rainbow Rush 🌈

A stage-based **obby** (obstacle course) starter game for Roblox, built with
[Rojo](https://rojo.space). The entire obstacle course is generated **in code at
server startup** — no manual Studio building required. Sync, press Play, and you're
running the course.

## Gameplay

- **24 stages across three themed zones** — **Meadow** (learn the ropes), **Ice**
  (slippery, vanishing footing), and **Volcano** (everything at once) — each with its
  own palette, materials, and hazard mix, named by a floating sign.
- Each platform starts with a glowing **checkpoint** that locks in your progress —
  your `Stage` shows on the leaderboard. **Lava strips** in the gaps reset you to
  your last checkpoint.
- Hazards: **moving platforms** slide side to side, **disappearing platforms** fade
  under your feet, **spinner kill-bars** sweep their platforms, **conveyors** push
  you backward, and **jump pads** launch you across extra-wide gaps.
- **Coins** spin over every platform (worth more in later zones) — spend them in the
  **Trail Shop** on six trail cosmetics that follow your character. Coins, owned
  trails, and your equipped trail are **saved between sessions**.
- A **live timer** runs from the first checkpoint to the finish; finishing pays a
  coin bonus (faster runs pay more), and your **Best** time is on the leaderboard,
  persisted, and ranked on the global **"Fastest Times" board** near spawn.
- Feedback everywhere: checkpoint chimes, coin dings, a finish fanfare with
  confetti, and fireworks when you set a new personal best.
- **Rebirth**: after finishing a run you can Rebirth — progress resets, you gain a
  **Rebirths** rank, a permanent **+25% coin multiplier per rebirth**, and a tiered
  aura (bronze → silver → gold → diamond → mythic). **Wins persist** between sessions.
- **Daily rewards**: a login streak pays escalating coins (day 7 caps the table and
  gifts the Rainbow Blaze trail). Miss a day and the streak resets.
- **Badges** (optional): First Win, 10 Wins, Speedrunner, Rich, and Reborn — create
  them on the Creator Dashboard and paste the ids into `Config.BADGE_IDS`.
- **Ghost replays**: race a translucent ghost of your **own best run** — your runs
  are recorded client-side (position + yaw, 10 Hz) and the server keeps the
  recording of your fastest one. Toggle with the 👻 button (or **D-pad Left**).
- HUD shows stage, timer, best time and coins, plus **Reset**, **Skip Stage**
  (gamepass), **Shop** and **Rebirth** buttons, and a daily-reward claim popup.
- **Cross-platform**: touch and mouse tap the HUD; on a controller (PlayStation /
  Xbox) **Reset = Triangle/Y**, **Skip Stage = Square/X**, **Shop = D-pad Up**,
  **Rebirth = D-pad Down** (jump stays on Cross/A), and the shop and daily popup
  are navigable with the gamepad.

## Project layout

```
default.project.json          # Rojo project — maps folders to Roblox services
src/
  server/
    init.server.luau          # Boots the game (ServerScriptService.Server)
    CourseBuilder.luau        # Procedurally builds the zoned course into Workspace
    HazardService.luau        # Moving, disappearing, spinner, conveyor, jump pad
    CheckpointService.luau    # leaderstats, checkpoints, respawn, lava, finish
    TimerService.luau         # Run timing + best-time tracking (player attributes)
    CoinService.luau          # Coin pickups, Coins leaderstat, finish bonus
    ShopService.luau          # Server-validated trail shop (buy/equip) + trails
    DataService.luau          # DataStores: best times, global ranks, profiles
    RebirthService.luau       # Rebirth rank, coin multiplier, tiered auras
    DailyRewardService.luau   # Login streak rewards + day-7 trail grant
    BadgeAwards.luau          # Roblox badges off the game's listener hooks
    GhostService.luau         # Ghost replays: submit-window validation + storage
    GlobalBoard.luau          # Physical "Fastest Times" sign near spawn
    GamepassService.luau      # Skip-stage gamepass + Skip button remote
    EffectsService.luau       # Sounds, confetti, PB fireworks, ambient music
  client/
    init.client.luau          # HUD + trail shop UI (StarterPlayerScripts.Client)
    Ghost.luau                # Ghost replays: run recording + local-only playback
  shared/
    Config.luau               # Tunables shared by server + client (ReplicatedStorage.Shared)
    ShopItems.luau            # Trail catalogue shared by shop UI + server validation
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

### Publishing for console (PS5 / Xbox)

1. Publish the place (*File → Publish to Roblox As…*) and set the experience to
   **Public** in the [Creator Dashboard](https://create.roblox.com).
2. In Studio, *Home → Game Settings → **Playable Devices*** → enable **Console** so
   it appears on PS5/Xbox. DataStores (best times / global board) work automatically
   in a published game.
3. On PS5, install **Roblox** from the PlayStation Store, sign in, and open the
   experience (favourite it on the web/app first to find it quickly). Move with the
   left stick, jump with **✕**; Reset/Skip are on **Triangle/Square**.

Prefer a one-shot place file instead of live sync? Build one with:

```
rojo build default.project.json --output RainbowRush.rbxlx
```

then open `RainbowRush.rbxlx` in Studio.

## Tuning

Most knobs live in [`src/shared/Config.luau`](src/shared/Config.luau): stage/zone
counts, platform/gap sizes, hazard speeds and timings, coin values and respawn,
finish/speed bonuses, sound ids, music, and the skip gamepass id. Each zone in
`Config.ZONES` declares its palette, material, friction, and an eight-slot
platform-kind `pattern` — edit those tables to re-theme or re-mix the course.
Trail cosmetics (names, prices, colours) live in
[`src/shared/ShopItems.luau`](src/shared/ShopItems.luau). Change a value, re-sync,
and the next server build reflects it.

## Coins, shop & persistence

- Coins respawn per-server after `COIN_RESPAWN` seconds; values scale by zone.
- The shop is fully server-validated (`ShopService`): the client can only ask.
  Purchases auto-equip; trails attach to the character on every spawn.
- Player profiles (coins, owned trails, equipped trail) are saved via
  `UpdateAsync` with a merge rule, debounced while online and flushed on leave
  and server shutdown — a lost race with another server never loses purchases.

## Sounds

Default sound effects use Roblox built-ins (`rbxasset://sounds/...`) so they work
with zero setup. For a richer soundscape, swap the ids in `Config.SOUNDS` for
catalogue audio (`rbxassetid://<id>`), and set `MUSIC_ID` to a licensed audio id
to enable the ambient loop.

## Best-time persistence & global board

Best times persist through `DataService`:

- A **DataStore** stores each player's own best (loaded on join, saved on improvement).
- An **OrderedDataStore** ranks best times (as integer milliseconds) to power the
  global **"Fastest Times"** board built near spawn by `GlobalBoard`.

This needs the DataStore API to be available: a **published** place, or Studio with
**Game Settings → Security → Enable Studio Access to API Services** ticked. If the API
is unavailable, `DataService` detects the failure, turns persistence off, and the game
still runs — the board just shows a hint instead of times. Toggle it all with
`USE_DATASTORE` in `Config`, and bump `BEST_STORE_NAME` / `GLOBAL_STORE_NAME` if you
ever want to wipe saved data.

## Notes

- Moving platforms are anchored and tweened; their checkpoint marker rides along each
  frame so it stays with the platform.
