# Roadmap and unfinished work

Phase 1 (this build) is the playable foundation. Each later phase must leave the game runnable and keep saved data compatible: bump `Schema.CURRENT_VERSION` and add a migration whenever the data shape changes.

## Phase 1: playable foundation ✔ built (needs a Studio pass)

- **Done:**
  - Project structure and profile saving.
  - Starter plot with 1 production building.
  - 3 starter creatures with job assignment.
  - HUD and windows.
  - 10-step tutorial.
  - Upgrades, placement, abilities and offline progress.
- **Open:** run the manual checklist in [TESTING.md](TESTING.md) in Studio and fix whatever it turns up. Nothing here has executed inside Roblox yet.

### Known limitations in Phase 1

- Creatures walk in straight lines across the flat plot and pass through buildings visually. There's no pathfinding yet.
- Placed buildings can't be moved or demolished.
- No audio assets are configured (the game is silent apart from the UI click), and creatures use code-built models with procedural animation. See [ASSETS.md](ASSETS.md).
- The cooldown shown in an open Creatures window doesn't count down live. The creature bar does.
- Only the Moonpetal chain exists, so Essence and Empire Shards are only granted by the last quest and have no use yet.
- Expansion zones, the Research Station, synergies and evolution are visible but not functional. They say so in the game.
- Creature nicknames exist in the data but there's no rename UI. Renaming needs `TextService` filtering.
- The plot count is fixed at 6. Set the place's max players to 6.

## Phase 2: core simulator

1. **Hatching** (`HatchingService`, `EggConfig`).
   - Egg types with loot tables from `CreatureConfig` species (`Phase <= 2`).
   - Published exact odds in the UI, and a pity counter saved per egg type (`PlayerData.Pity[eggId]`) with clear reset rules.
   - The hatch sequence reuses `RevealOverlay`.
   - Eggs cost Gold or Essence only. Robux eggs need a compliant disclosure flow and are not planned.
2. **Evolution** (`EvolutionService` and an Evolution Chamber building). Requirements are already in config: `Level`, `WorkCycles`, `Essence`, plus new kinds. On evolving:
   - set `Stage`
   - change abilities through `Evolution[stage].Unlocks`
   - rebuild the model (the anchor's `Stage` attribute triggers this already)
3. **Second production chain.**
   - Crystal Mine (Miner job), Smelter (input recipe) and Essence Condenser.
   - ProductionService then has to consume inputs: pull from building storage or the silo, and stop when inputs run out.
   - Add Raw Crystal, Refined Crystal and Arcane Core to `ResourceConfig`, and enable the recipes in `RecipeConfig`.
4. **Upgrades and expansion.**
   - Expansion zones become purchasable: a saved `PlotExpansions` list widens the grid bounds in `Grid.InBounds`.
   - Building move and demolish (Grid already supports `ignoreId`).
5. **Inventory UI** for materials and items, and a collection journal with per-species records (first found, best mutation).

## Phase 3: world and exploration

1. Emberfall Basin region: terrain, landmarks, lighting and its heat mechanic (`BiomeConfig`).
2. Resource nodes. These are server-validated gather actions with distance checks and respawn timers.
3. Wild encounters and rescue missions that grant creatures (`CreatureService.Grant(..., "Wild")`).
4. Expeditions (`ExpeditionService`):
   - Pick creatures, supplies and a destination. Timed or active.
   - Success uses Exploration, CombatPower and Luck, plus player choices.
   - Fatigue is a saved field on creatures.
5. The first guardian fight with telegraphs and phases, and region quests.

## Phase 4: advanced empire systems

1. **Synergies.**
   - `SynergyConfig` lists pairs of families or species working at the same building, or within N cells.
   - Each synergy is a bonus in the existing `Synergy` category, so it is capped automatically.
   - Show active synergies in the BuildingPanel's Synergies section, which is already there.
2. **Research tree** (unlock the Research Station, Researcher job).
3. **Mutations.**
   - A deterministic roll on hatch or evolve, using a seed of creature id and event.
   - Probabilities in `MutationConfig`, a visual layer in CreatureModels, and capped stat effects.
4. **Ascension.**
   - Reset the listed sections and keep `Ascension`, `Receipts`, settings and the collection.
   - Grant Empire Shards.
   - Show a full "what resets / what stays" summary before confirming.
5. More biomes, recipes and automation buildings (couriers, conveyors as visuals over logical transfers).

## Phase 5: multiplayer

1. **Plot permissions** (visitor, collaborator, owner) checked in `Net` handlers. A saved list of collaborator user ids.
2. **Trading** (`TradingService`):
   - Two-player sessions, an offer summary, and both players confirming again after any change.
   - Ownership is re-checked at commit, and both profiles are updated in one server-side step.
   - Cancel on disconnect.
   - Respect `Tradable` and `EconomyConfig.Trading`. Starter and quest creatures are already untradable.
3. Cooperative expeditions and world events (`WorldEventService`).
4. Leaderboards with OrderedDataStores: empire progression, efficiency, collection, expeditions, seasonal.

## Phase 6: polish and release

1. Import the assets from [ASSETS.md](ASSETS.md). Play `AssetConfig.Animations` when a species has rigged animations.
2. Pathfinding for creatures (PathfindingService with the straight-line fallback), only for creatures near a player.
3. Optional monetization (`MonetizationService`):
   - Product ids in config, `ProcessReceipt` with an idempotent grant recorded in `PlayerData.Receipts` before returning `PurchaseGranted`.
   - Game pass checks through MarketplaceService.
   - Cosmetics and convenience only.
4. Exploit pass, DataStore failure drills, a 6-player performance test, and the release checklist in [TESTING.md](TESTING.md).
