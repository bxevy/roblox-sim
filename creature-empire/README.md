# Creature Empire

A creature-collecting simulator and empire-building tycoon for Roblox, written in Luau and managed with [Rojo](https://rojo.space).

You start with a small plot, one partner creature and a single Moonpetal Farm. Creatures walk to their jobs and work there. You collect the harvest, sell it, and grow the farm into a glowing empire.

This folder contains **Phase 1 (the playable foundation)**, **Phase 2 (the core simulator: hatching, evolution, a second production chain and land expansion)** and **Phase 3 (the first explorable region: Emberfall Basin, wild creatures, expeditions and a guardian fight)**. The [roadmap](docs/ROADMAP.md) lists what Phases 4–6 add and exactly what is unfinished.

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

## Added in Phase 2

- **Hatchery and eggs.** Three eggs: Meadow (Gold), Ember (Gold and Raw Crystal) and Geode (Essence and Refined Crystal).
  - Exact odds are listed before every hatch, with rarity glyphs and words.
  - Pity: a Rare or better is guaranteed within 15 hatches (12 for Geode). The counter is shown and resets when you hatch one.
  - The hatch plays an egg-coloured reveal. Eggs never cost Robux.
- **13 obtainable species** (up from 3), including four Rares and an Epic (Prismaw). Every obtainable species has a real job and a passive that actually does something.
- **Evolution Chamber.** Creatures evolve to Mature and Ascended forms once they meet their requirements: level, work cycles in a specific job, Essence or materials.
  - Each stage adds +15% / +30% speed and yield and makes the active ability 50% / 100% stronger (longer for speed bursts).
  - Some species' job skills improve, and they gain new visual features (flower crown, flame tuft, aura, halo).
  - The Creatures window shows a live checklist and an Evolve button.
- **Crystal chain.**
  - Crystal Mine (Miner) → Raw Crystal → Crystal Smelter (Smelter, uses 3 Raw from your silo) → Refined Crystal → Essence Condenser (new Alchemist job, uses Refined Crystal + Moonpetals) → Essence.
  - Buildings pause with a clear message when the silo runs out of inputs, which makes bottlenecks easy to spot.
  - Empire Core tiers 3–5, the late silo and habitat levels, and land need Refined Crystal.
- **Land expansion.** Buy the West Meadow, East Grove and North Ridge from the Empire Core panel. The fence moves out and the land becomes buildable.
- **Move buildings.** Use *Move this building* in any placeable building's panel.
- **Habitat capacity** (6 → 30 across 5 levels) limits hatching. Upgrade it to keep more creatures.
- **Inventory window** (G) listing every currency and material, what it's for and its storage limit.
- **7 more quests** that lead through hatching, mining, smelting, evolving and Empire Core tier 3.
- **Saves move to schema v2.** Old v1 profiles migrate automatically: earlier work counts as farming, and pity and expansions are added.

## Added in Phase 3

- **Emberfall Basin**, a volcanic region reached through the gate in the central plaza (Empire Core tier 2), or from the World Map (M).
  - Lava rivers with bridges, cooling pools, timed vents that glow before they erupt, an ash-filled sky and colour grading.
  - **Heat** builds while you explore and spikes on lava and erupting vents. Blue pools cool you. A fire-resistant companion (Emberkin, Tideborn) slows it. At 100% heat your creatures carry you back to the gate; nothing is lost.
  - **Eruptions** every 8 minutes for 90 seconds: hotter, darker, and a rare Pyrewing circles the Ashen Overlook.
- **Resource nodes.** Emberstone deposits and crystal clusters. Hold E to gather; the server checks distance and each node's personal cooldown. A companion can find bonus materials.
- **Companions.** *Take with me* in the Creatures window: the creature follows you everywhere, helps befriend and gather, and resists heat.
- **Wild creatures and befriending.** Up to 5 wild creatures roam the basin. Craft an **Ember Lure** at the Trading Post (5 Emberstone + 10 Moonpetals) and throw it. The window shows the exact chance first (rarity, same-family companion +15%, Luck). Win or lose, the creature leaves.
- **Discoveries.** 5 landmarks, including a hidden grotto (follow the glowing footprints). Each pays a one-time reward and is listed in the map's journal.
- **Expedition Portal** (new building, tier 2). Send 1–3 creatures to the Foothills (5 min), Tunnels (15 min) or Caldera Rim (45 min).
  - Pick an approach (Cautious, Balanced, Bold) and supplies (Heat Shield, Rations). The success chance is shown live and uses the team's Exploration, CombatPower and Luck against the recommended stats.
  - Results are rolled from a seed saved at launch, so rejoining never re-rolls. Failures still return 25% of the loot. Creatures rest afterwards (unless you packed Rations) and gain XP and Explorer cycles. Some trips find new creatures.
- **Guardian: the Magmaul Matriarch** in the caldera. Cooperative: everyone nearby fights with their companion (1 = Attack, 2 = Special, or the on-screen buttons). Slams are telegraphed with filling circles; step out of them. Three phases, health scales with players, rewards are shared by contribution, and the first win grants a Magmaul.
- **Emberstone** material, **Pyrewing** and **Coilhorn** become obtainable, and the Explorer job is live.
- **7 more quests** that lead through the basin, gathering, discoveries, crafting, befriending, an expedition and the guardian.
- **Saves move to schema v3.** Older profiles migrate automatically.

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
| Inventory          | G                     | Inventory button       | Inventory button    |
| Close window       | ✕ / click outside     | B                      | ✕ / tap outside     |
| Placement          | R rotate, click place, X / right-click cancel | Y rotate, A place, B cancel | tap ground, then Rotate / Place / Cancel |

## Project layout

```
creature-empire/
  default.project.json      Rojo project (ReplicatedStorage.Shared, ServerScriptService.Server, StarterPlayerScripts.Client)
  src/shared/               → ReplicatedStorage.Shared
    Config/                 every number and definition: creatures, jobs, buildings, recipes,
                            resources, rarities, eggs, economy, quests, biomes, plots, assets, game
    Util/                   pure shared logic: Formulas, Production, Grid, Hatching, Evolution, Format
    Types.luau, Remotes.luau
  src/server/               → ServerScriptService.Server
    Bootstrap.server.luau   starts everything
    Core/                   ProfileCore (session locks), Schema (defaults/migrations/repair),
                            Net (validated remotes), RateLimiter, Events, Signal, Log
    Services/               PlayerData, State, Economy, Plot, Building, Production, Creature,
                            Hatching, Evolution, Quest, Settings, AntiExploit, Dev
    World/                  WorldBuilder (Verdant Reach), BuildingModels, Parts
  src/client/               → StarterPlayer.StarterPlayerScripts.Client
    Main.client.luau
    Controllers/            State, UI, Creature, Building, Placement, Tutorial, Effects, Audio, Input
    UI/                     Theme, Window, Hud, CreaturesWindow, BuildingPanel, BuildMenu,
                            StarterSelect, RevealOverlay, SettingsWindow, QuestJournal, InspectWindow,
                            InventoryWindow
    Visuals/CreatureModels  code-built creature models
  tests/                    Lune test suite (93 tests): `lune run tests/run`
  docs/
```

The spec suggested `StarterGui` folders for each UI. Here the interface is built from code by client modules instead, so a layout change is a code review rather than a binary diff. Each window is still its own module.
