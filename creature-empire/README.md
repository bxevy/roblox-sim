# Creature Empire

A creature-collecting simulator and empire-building tycoon for Roblox, written in Luau and managed with [Rojo](https://rojo.space).

You start with a small plot, one partner creature and a single Moonpetal Farm. Creatures walk to their jobs and work there. You collect the harvest, sell it, and grow the farm into a glowing empire.

This folder is **Phase 1: the playable foundation**. The [roadmap](docs/ROADMAP.md) lists what Phases 2–6 add and exactly what is unfinished.

| Doc                                       | What's in it                                                       |
| ----------------------------------------- | ------------------------------------------------------------------ |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the code is organised, data flow, security model, extending it |
| [docs/TESTING.md](docs/TESTING.md)           | Automated tests, the manual test checklist, debugging guide        |
| [docs/ASSETS.md](docs/ASSETS.md)             | Asset manifest: sounds, images, models and animations to import    |
| [docs/ROADMAP.md](docs/ROADMAP.md)           | Phase plan, unfinished systems and the steps to finish them        |

## What works in Phase 1

- **Starter choice.** Pick Sproutling (Verdant farmer), Cindercub (Emberkin worker) or Pebblit (Crystalkin digger). The tutorial gives you the other two along the way.
- **Your plot.** A protected 24×24-cell plot with:
  - an Empire Core
  - a creature habitat
  - a Resource Silo
  - a Trading Post
  - a Research Station (still under construction)
  - roped-off expansion zones
  - a free Moonpetal Farm
- **Creature jobs.** Assign creatures to farms. Each species farms at a different skill level, and level and passive abilities add to that. Creatures walk to the farm, work there and show their harvest. When they have no job they wander the habitat.
- **Active abilities.**
  - Bloom Burst instantly adds crops to the farm.
  - Kindle speeds up every worker at its building.
  - Rockseek digs up gold.
- **Production.** The server computes output from elapsed time and saved state, and stops when storage is full.
  - Offline progress runs at 50% for up to 2 hours.
  - Creatures gain XP and levels while they work.
- **Economy.**
  - Collect Moonpetals into the silo, then sell them for Gold at the Trading Post.
  - Upgrade the farm (5 levels: more slots, storage, speed and a visible new stage each time).
  - Upgrade the silo (5 levels).
  - Upgrade the Empire Core (5 tiers). Each tier raises the farm limit and creature yield.
  - Build more farms with a grid placement preview.
- **Onboarding.** A 10-step questline with a guide trail to each target, claimable rewards and a quest journal.
- **Interface.**
  - HUD: wallet, empire tier progress, quest tracker, creature bar with ability cooldowns.
  - Windows: Creatures (details, job assignment, collection journal for all 32 designed species), building panels, Build menu, Settings.
  - A creature reveal animation.
  - A read-only "Inspect empire" view of other players' plots.
- **Saving.** Versioned profiles with migrations and repair on load.
  - Session locking means two servers never write the same player.
  - Retries with backoff, dirty-flag autosave, save on leave and on shutdown.
  - A failed load never becomes a fresh profile.
- **Security.** Every request is validated on the server (ownership, distance, prices, slots, input types) and rate-limited.

## Run it

### Option A: open the built place

The ready-to-open place file is `creature-empire.rbxl`. To rebuild it:

```bash
cd creature-empire
rojo build -o creature-empire.rbxl
```

### Option B: live sync with Rojo

1. Install the tools from the repo root: `rokit install` (Rojo 7.4.4, StyLua and Selene).
2. Run `cd creature-empire && rojo serve`.
3. In Studio, open a new Baseplate place, delete the `Baseplate` part, then connect with the Rojo plugin.

### Studio settings (once per place)

1. **Max players: 6.** Each plot is one player (Game Settings → Places → Server Fill / Max Players). A 7th player would be told the server is full.
2. **Saving in Studio is optional.** Without *Game Settings → Security → Enable Studio Access to API Services* the game runs normally, but the HUD says "progress is not saved".
   - When publishing for real, turn API access on and test a save and load round trip (see [TESTING.md](docs/TESTING.md)).
3. **Developer tools** are in *Settings → Developer* when playing in Studio. Use them to add gold, fill storage, skip quests, simulate time away, and so on. In live servers they're only available to user ids listed in `src/shared/Config/GameConfig.luau`.

## Controls

| Action             | Keyboard / mouse      | Gamepad                | Touch               |
| ------------------ | --------------------- | ---------------------- | ------------------- |
| Collect at a farm  | E (prompt)            | X                      | tap the prompt      |
| Manage a building  | F (prompt)            | Y                      | tap the prompt      |
| Creatures window   | C                     | D-pad up               | Creatures button    |
| Build menu         | B                     | D-pad left             | Build button        |
| Quest journal      | J                     | D-pad right            | Quests button       |
| Settings           | P                     | D-pad down             | Settings button     |
| Close window       | ✕ / click outside     | B                      | ✕ / tap outside     |
| Placement          | R rotate, click place, X / right-click cancel | Y rotate, A place, B cancel | tap ground, then Rotate / Place / Cancel |

## Project layout

```
creature-empire/
  default.project.json      Rojo project (ReplicatedStorage.Shared, ServerScriptService.Server, StarterPlayerScripts.Client)
  src/shared/               → ReplicatedStorage.Shared
    Config/                 every number and definition: creatures, jobs, buildings, recipes,
                            resources, rarities, economy, quests, biomes, plots, assets, game
    Util/                   pure shared logic: Formulas, Production, Grid, Format
    Types.luau, Remotes.luau
  src/server/               → ServerScriptService.Server
    Bootstrap.server.luau   starts everything
    Core/                   ProfileCore (session locks), Schema (defaults/migrations/repair),
                            Net (validated remotes), RateLimiter, Events, Signal, Log
    Services/               PlayerData, State, Economy, Plot, Building, Production, Creature,
                            Quest, Settings, AntiExploit, Dev
    World/                  WorldBuilder (Verdant Reach), BuildingModels, Parts
  src/client/               → StarterPlayer.StarterPlayerScripts.Client
    Main.client.luau
    Controllers/            State, UI, Creature, Building, Placement, Tutorial, Effects, Audio, Input
    UI/                     Theme, Window, Hud, CreaturesWindow, BuildingPanel, BuildMenu,
                            StarterSelect, RevealOverlay, SettingsWindow, QuestJournal, InspectWindow
    Visuals/CreatureModels  code-built creature models
  tests/                    Lune test suite (65 tests): `lune run tests/run`
  docs/
```

The spec suggested `StarterGui` folders for each UI. Here the interface is built from code by client modules instead, so a layout change is a code review rather than a binary diff. Each window is still its own module.
