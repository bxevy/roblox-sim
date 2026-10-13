# Roadmap and unfinished work

Phases 1 and 2 are built. Each later phase must leave the game runnable and keep saved data compatible: bump `Schema.CURRENT_VERSION` and add a migration whenever the data shape changes (v1 → v2 is the worked example).

## Phase 1: playable foundation ✔ built

- **Done:**
  - Project structure and profile saving.
  - Starter plot with 1 production building.
  - 3 starter creatures with job assignment.
  - HUD and windows.
  - 10-step tutorial.
  - Upgrades, placement, abilities and offline progress.

## Phase 2: core simulator ✔ built

- **Hatching.** `HatchingService`, `EggConfig` and `Shared/Util/Hatching`: 3 eggs, exact odds and a pity counter for each egg type.
- **Evolution.** `EvolutionService`, `Shared/Util/Evolution` and the Evolution Chamber: stage stat bonus, stronger abilities, job skill overrides and new features.
- **Second production chain.** Crystal Mine → Smelter → Essence Condenser. Recipes consume silo materials (`Production.Step`) and pause when inputs run out.
- **Land and buildings.**
  - Land expansion (3 zones, a moving fence) and building move.
  - Habitat capacity levels.
  - Refined Crystal costs at major milestones.
- **Interface and content.** Inventory window, 13 obtainable species, 7 new quests.
- **Save data.** Schema v2 with the v1 → v2 migration.

**Open for both phases:** run the manual checklist in [TESTING.md](TESTING.md) in Studio. Nothing has executed inside Roblox yet. Everything except the engine-facing code is covered by 93 automated tests and type checking.

### Known limitations

- Creatures walk in straight lines and pass through buildings visually. There's no pathfinding yet.
- Buildings can be moved but not demolished.
- No audio assets are configured (the game is silent apart from the UI click), and creatures use code-built models with procedural animation. See [ASSETS.md](ASSETS.md).
- Couriers, conveyors and power don't exist yet. Smelters and condensers pull straight from the silo.
- Empire Shards are granted by one quest and have no use until Ascension (Phase 4).
- The Research Station and synergies are visible but not functional; the game says so.
- Starters' Ascended forms need long-term work (1,500 job cycles). Phase 3 expeditions won't retroactively add requirements.
- Creature nicknames exist in the data but there's no rename UI. Renaming needs `TextService` filtering.
- The plot count is fixed at 6. Set the place's max players to 6.

## Phase 3: world and exploration ✔ built

- **Region.** `RegionConfig` (layout, heat tuning, vent and eruption cycles on the shared server clock), `World/EmberfallBuilder` (terrain, lava, bridges, pools, vents, landmarks, caldera, gates) and `RegionService` (travel, heat, rescue, discoveries). The client mood and vent visuals live in `RegionController`.
- **Resource nodes.** `NodeService`: per-player cooldowns, distance checks and companion bonus rolls.
- **Wild encounters.** `WildService` spawns from a weighted table and an eruption-only Pyrewing. Befriending consumes an Ember Lure (`CraftingService`, `CraftConfig`). The chance comes from `Shared/Util/Encounter`.
- **Expeditions.** `ExpeditionService`, `ExpeditionConfig` and `Shared/Util/Expedition`: seeded outcomes, approaches, supplies, rest (the saved `RestUntil` field on creatures) and an Expedition Portal with 1–3 slots.
- **Guardian.** `GuardianService` and `CombatConfig`: three phases, telegraphed slams that add heat, health scaling with players, contribution-shared rewards with a cooldown, and a first-win creature. `GuardianController` draws it.
- **Interface.** World Map with a region journal (M), Befriend window, expedition planner and report, Trading Post crafting, companion controls, and the heat and combat HUD.
- **Content and data.** 7 region quests, Emberstone, Ember Lure, Pyrewing and Coilhorn. Schema v3.

**Open for Phase 3:** the manual checklist in [TESTING.md](TESTING.md). The region geometry, heat feel, guardian balance and companion following have only been checked by reading the code, not by playing.

### Phase 3 known limitations

- Guardian combat is "stand near and press attack" with your companion's stats. There's no dodging the guardian except walking out of the telegraphs.
- Wild creatures wander in straight lines and pass through rocks. Companions teleport to you if they fall more than 60 studs behind.
- Rescue missions (the spec's "wild encounters and rescue missions") are covered by the expedition events; there's no separate rescue mode.
- Only Emberfall is built. Other biomes show in the map as later updates.
- Boltbug, Runemoth, Shadeling and Bubblot moved to Phase 4 because their abilities need Phase 4 systems.

## Phase 4: advanced empire systems ✔ built

- **Research.** The Research Station works: researchers turn Moonpetals into Insight (`StudyInsight`). `ResearchConfig` has 10 nodes in 4 branches. Their effects are production bonuses (category `Research`), silo size, offline hours, expedition chance, heat resistance, mutation odds, synergy strength, and unlocking the Courier Post. `ResearchService` buys nodes; `Shared/Util/Research` applies them.
- **Synergies.** `SynergyConfig` has 9 synergies: family pairs per job, three of a family, and the three starters together. `Production.Rates` works out each building's crew first, then adds capped `Synergy` bonuses. The building panel lists active and possible synergies.
- **Automation.** The Courier Post (research: Courier Routes) uses the new Courier job: couriers carry stored output to the silo or wallet, fullest building first, in batches every 5 s, and stop when the silo is full. Gearhound's *Fetch* (new `Collect` ability) carries a batch instantly.
- **Mutations.** Prismatic, Ancient and Shadow (`MutationConfig`). Each is rolled deterministically from creature id + event when a creature hatches, is befriended, comes back from an expedition, or evolves. They recolour the model, add a sparkle and give a capped bonus. The odds are listed in the Hatchery.
- **Ascension.** At Empire Core tier 5, from the Empire Core panel:
  - Resets gold, Essence, Insight, materials, buildings, land and research.
  - Keeps creatures, the collection, discoveries, quests, pity, lures and perks.
  - Pays `10 × √(run gold / 100k)` Empire Shards (minimum 10) and adds +10% yield per Ascension.
  - Shards buy 5 permanent perks.
  - The first Ascension grants Titanicore.
  - The whole reset is the pure `Shared/Util/Ascension.Apply`, which is unit-tested.
- **Content.** Arcane Egg (Insight + Essence). Runemoth, Starweaver, Bubblot, Coralisk, Boltbug, Gearhound and Titanicore become obtainable, with working abilities and passives. 7 new quests. Schema v4.

**Open for Phase 4:** the manual checklist in [TESTING.md](TESTING.md). Nothing in it has run inside Roblox yet.

### Phase 4 known limitations

- Couriers make one delivery for a whole offline period. Storage caps it, so they move less than they would have online.
- After an Ascension the Habitat is back to level 1. You keep every creature, but hatching and befriending wait until the Habitat has room again.
- Players who migrate from a Phase 3 save get their first Ascension payout from all the gold they ever earned.
- Only one new automation building. Conveyors, power and the Mutation Lab are still to come, and so are the Alchemy Lab recipes and new biomes.
- These species were moved to Phase 5 because their abilities need systems that don't exist yet:
  - Elderbark (Verdant guardian)
  - Thundermaw (power)
  - Voidlark (teleport)
  - Shadeling (stealth)
  - Duskfang (debuff)
  - Nocturnox (mutate)
  - Abyssquid (relic jobs)
- PowerOperator, Breeder and RelicInvestigator jobs are Phase 5.

## Phase 5: multiplayer ✔ built

- **Plot permissions.** `SocialService.Permission` returns Owner, Collaborator or Visitor. Each owner keeps a saved list of up to 5 collaborators. Collaborators can collect the owner's harvests into the owner's silo (`CollectFor`) and nothing else. Visitors can inspect and cheer. Cheering an Empire Core gives the owner's production buildings +10% work speed (`Boost`) for 10 min: up to 3 cheers stack, each visitor can cheer each empire once per 10 min, and the cheerer gets a small gift.
- **Trading.** `TradingService` plus the pure `Shared/Util/Trade`:
  - **Session:** an invite, then both offers (up to 4 creatures plus listed resources).
  - **Confirming:** ready ticks clear on any change, then a 3 s countdown that any change also cancels.
  - **Committing:** a full re-check of ownership, tradability, companions, expeditions, habitat and silo room, then one no-yield swap and an immediate save of both profiles.
  - **Cancelling:** nothing moves on cancel or disconnect.
  - **What can't be traded:** starter, quest and gift creatures.
- **World events.** `WorldEventService` runs on a schedule computed from the shared server clock: one event every 15 minutes.
  - **Golden Hour:** a server-wide +25% work-speed buff.
  - **Grand Bloom:** the whole server collects Moonpetals toward one goal. If it's reached, every helper is rewarded, and a player's first win also grants Elderbark.
  - **Ember Rift:** a cooperative expedition. Teams join from the Expedition Portal without using a slot, and every extra team adds +6% success for everyone (capped at +30%). Results stay seeded, and a team that left the server is resolved solo.
- **Leaderboards.** `LeaderboardService` keeps OrderedDataStore boards for Empire score, Collection, Explorers and Weekly gold (a key per week, starting Monday UTC). There's a board in the plaza and a Rankings window. Every call is protected, and the board says so when DataStores are unavailable.
- **Content.** Elderbark (Rootwall heat shield for nearby allies), Duskfang (Night Howl: the guardian takes +30% damage), Voidlark (Fold: running expeditions return 5 min sooner) and Shadeling (Veil: no heat build-up). Their abilities run through `CreatureService.AbilityHandlers`. There's 1 new quest, and saves move to schema v5.

**Open for Phase 5:** run the manual checklist in [TESTING.md](TESTING.md) with 2–3 players (Studio → Test → Clients and Servers). Nothing in it has run in Roblox yet.

### Phase 5 known limitations

- Trades save both profiles right after the swap. If the server crashes between those two saves, one side could roll back. Session locks rule out cross-server duplication.
- Collaborators can't build or assign; they only collect, and the harvest goes to the owner.
- Leaderboards need a published game (or Studio API access).
- Thundermaw, Nocturnox and Abyssquid, and the PowerOperator, Breeder and RelicInvestigator jobs, are Phase 6. Cross-server friends and party invites are not included.

## Phase 6: polish and release

1. Import the assets from [ASSETS.md](ASSETS.md). Play `AssetConfig.Animations` when a species has rigged animations.
2. Pathfinding for creatures (PathfindingService with the straight-line fallback), only for creatures near a player.
3. Optional monetization (`MonetizationService`):
   - Product ids in config, `ProcessReceipt` with an idempotent grant recorded in `PlayerData.Receipts` before returning `PurchaseGranted`.
   - Game pass checks through MarketplaceService.
   - Cosmetics and convenience only.
4. Exploit pass, DataStore failure drills, a 6-player performance test, and the release checklist in [TESTING.md](TESTING.md).
