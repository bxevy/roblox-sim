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
