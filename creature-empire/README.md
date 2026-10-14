# Creature Empire

A creature-collecting simulator and empire-building tycoon for Roblox, written in Luau and managed with [Rojo](https://rojo.space).

You start with a small plot, one partner creature and a single Moonpetal Farm. Creatures walk to their jobs and work there. You collect the harvest, sell it, and grow the farm into a glowing empire.

This folder contains **Phase 1 (the playable foundation)**, **Phase 2 (the core simulator: hatching, evolution, a second production chain and land expansion)** **Phase 3 (the first explorable region: Emberfall Basin, wild creatures, expeditions and a guardian fight)** **Phase 4 (research, synergies, courier automation, mutations and Ascension)** **Phase 5 (multiplayer: trading, collaborators, cheering, world events and leaderboards)** and **Phase 6 (polish and release: pathfinding, imported art, optional shop, renaming and the full roster)**. The [roadmap](docs/ROADMAP.md) lists ideas for later updates and exactly what is unfinished.

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

## Added in Phase 4

- **Research Station.** Assign researchers (Wisplet, Runemoth, Starweaver, Bubblot) to turn Moonpetals into **Insight**, then spend it on a 10-node research tree. Production, logistics, exploration and arcane branches give bigger yields, a bigger silo, longer offline hours, better expeditions, heat wards, stronger synergies and double mutation odds.
- **Synergies.** The right creatures working side by side boost each other. For example, a Verdant and an Emberkin farming together give +15% yield, and three of one family at a building give +10%. Every building panel shows which synergies are active and which are possible.
- **Courier Post.** Unlocked by research. Couriers (Cogling, Boltbug, Gearhound) carry harvests to your silo on their own, fullest building first.
- **Mutations.** Prismatic, Ancient and Shadow creatures look different and work a little better. There's a small chance each time a creature hatches, is befriended, comes back from an expedition, or evolves. The Hatchery shows the exact odds.
- **Ascension.** At Empire Core tier 5 you can start a fresh run. You keep every creature, earn Empire Shards and get +10% yield per Ascension. The window lists exactly what resets and what stays before you confirm. Spend shards on 5 permanent perks. Your first Ascension brings Titanicore.
- **Arcane Egg** (Insight + Essence) and **7 newly obtainable species**, all with working jobs and abilities. That includes Gearhound's *Fetch*, which hauls everything to the silo at once.
- **New models** for the Research Station, Courier Post and Expedition Portal.
- **7 more quests** and **schema v4**. Older saves migrate automatically.

## Added in Phase 5

- **Players window (U).** Lists everyone in the server. From it you can visit their plot, inspect it, invite them to trade, or make them a collaborator.
- **Trading.** Swap up to 4 creatures (plus Ember Lures). Gold and materials can't be traded, so nobody can park wealth on a friend through an Ascension or sell gold.
  - Both players see exactly what they'll get.
  - Any change clears both "Ready" ticks, and a short countdown runs before the swap.
  - The server re-checks everything at the end, then saves both profiles.
  - Starter, quest and gift creatures can't be traded.
- **Collaborators.** Chosen friends can collect your harvests into *your* silo, and can't do anything else.
- **Cheering.** Press *Cheer!* at another player's Empire Core. Their creatures work 10% faster for 10 minutes, and you get a small thank-you gift.
- **World events** every 15 minutes, shown top right:
  - **Golden Hour:** everyone's creatures work 25% faster.
  - **Grand Bloom:** a server-wide Moonpetal goal. Your first win brings Elderbark.
  - **Ember Rift:** a cooperative expedition. Every team that joins makes everyone's trip safer, and it can bring home Duskfang, Voidlark or Shadeling.
- **Leaderboards.** A board in the plaza and a Rankings window (L): greatest empires, collectors, explorers and this week's earners.
- **4 new species** with team-play abilities:
  - **Rootwall:** a heat shield for nearby allies.
  - **Night Howl:** the guardian takes more damage.
  - **Fold:** expeditions come back sooner.
  - **Veil:** no heat build-up.
- **Schema v5.**

## Added in Phase 6 (release)

- **Creatures walk around buildings** instead of through them.
- **Your own 3D creatures.** Drop a model (for example an imported FBX) into `ReplicatedStorage › Assets › Creatures` and it replaces that species everywhere. Rigged models play Idle, Walk and Work animations. See `docs/ASSETS.md`.
- **Rename your creatures.** Names go through Roblox text filtering.
- **Optional shop (K).** A cosmetic Supporter pass and a 30-minute production boost. Nothing random is ever sold. Items stay "Coming soon" until you add your own ids in `MonetizationConfig`.
- **All 32 species are obtainable.** The last three:
  - **Thundermaw:** a rare Caldera Rim find.
  - **Nocturnox:** a rare Ember Rift find; its Dark Gift triples the mutation chance of your next hatch.
  - **Abyssquid:** a rare Tunnels find; it dives for treasure.
- **Solid ground.** The plaza, plots and Emberfall floor are flat, so nothing sinks into the grass.
- **Schema v6.**

## Added in 1.1 (plaza update)

- **The plaza is the shop area.** The Trading Post (sell and craft) and the Hatchery nest moved off every plot into the plaza, where everyone shares them. Players who had built a Hatchery get its 400 gold back.
- **Spin Wheel.** One free spin every 30 minutes, at the wheel in the plaza. Prizes, with exact odds shown on the wheel:
  - 500 / 1,000 / 2,500 / 5,000 Gold
  - 25 Essence
  - **2× Coins** for 30 minutes (double gold from selling and abilities)
  - **2× Luck** for 30 minutes (rare-or-better creatures twice as likely from eggs)
  - the super rare **Black Dragon** (Mythic, 0.3%)

  Spins are only ever free; they are never sold. The HUD shows when your next free spin is ready and any boosts that are running.
- **Schema v7.**

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
