# Architecture

## Principles

1. **The server owns every outcome.** Clients send intentions ("collect farm1", "place a farm at 4,10 facing east"). The server checks them and decides results. Prices, rewards, output, damage and ownership never come from a client.
2. **Configuration drives content.** A new creature, building, recipe, quest step or biome is a config entry. Services read the configs; they don't special-case content.
3. **Pure logic is shared and tested.** Production maths, bonus stacking, grid placement, schema repair and session locking have no engine dependencies. The client previews with the same code the server enforces, and the Lune suite tests it.
4. **Simulate logically, show lightly.** Production is computed from elapsed time and saved state. Creatures are animated on each client from a few replicated attributes, so nothing physical drives the economy.

## Runtime layout

| Roblox location                              | Source        | Contents                                               |
| -------------------------------------------- | ------------- | ------------------------------------------------------ |
| `ReplicatedStorage.Shared`                   | `src/shared`  | Config, Util, Types, Remotes                           |
| `ServerScriptService.Server`                 | `src/server`  | Bootstrap, Core, Services, World                       |
| `StarterPlayer.StarterPlayerScripts.Client`  | `src/client`  | Main, Controllers, UI, Visuals                         |
| `Workspace.WorldRegions` (built at runtime)  | WorldBuilder  | Verdant Reach terrain, plaza, paths, scenery           |
| `Workspace.PlayerPlots.PlotN` (runtime)      | PlotService   | `Ground`, `Buildings/<id>` models, `Creatures/<id>` anchors |
| `ReplicatedStorage.CreatureEmpireRemotes`    | Remotes       | RemoteEvents / RemoteFunctions                         |

## Server services

Bootstrap starts the services in this order. PlayerDataService starts last, so every listener is connected before the first profile loads.

| Service             | Responsibility |
| ------------------- | -------------- |
| `PlayerDataService` | Loads and saves profiles through `Core/ProfileCore` (session locks, retries). Runs migrations and repair via `Core/Schema`. Handles dirty-flag autosave, saving on leave and `BindToClose`. Fires `Loaded` and `BeforeRelease`. |
| `StateService`      | Replicates each player's own state in sections (`Wallet`, `Buildings`, `Creatures`, `Quests`, `Collection`, `Settings`, `Meta`, `Dev`). Pushes are coalesced and flushed every 0.15 s. |
| `EconomyService`    | The only code that changes balances. Every change is finite, non-negative and capped. Material capacity comes from the silo. Spending is all-or-nothing. |
| `PlotService`       | Builds the 6 plots and assigns one per player. Converts grid cells to world CFrames. Sends players home on respawn. Serves the visitors' read-only inspect view. |
| `BuildingService`   | Place, upgrade, collect and sell. Checks bounds and collisions with `Shared/Util/Grid`, the core-tier limits and gates, cost, distance and rate. Spawns building models. |
| `ProductionService` | One loop for the whole server. Caches rates per player (`Shared/Util/Production`), advances storage by elapsed time, grants XP, handles ability buffs and applies offline progress. |
| `CreatureService`   | Grants creatures (GUID ids), the starter choice, job assignment, active abilities (with saved cooldowns) and the replicated creature anchors. |
| `HatchingService`   | Hatches eggs at the Hatchery: checks habitat space, spends the cost, rolls with `Shared/Util/Hatching` (the same code that publishes the odds), updates pity, grants the creature (tradable, source "Egg"). |
| `EvolutionService`  | Evolves creatures at the Evolution Chamber. Checks requirements with `Shared/Util/Evolution` (the same checklist the client shows) and only takes the costs once everything is met. |
| `QuestService`      | Tutorial steps checked by named evaluators. Step counters are driven by `Core/Events`. Rewards are claimed and granted once. |
| `SettingsService`   | Validated, saved player settings. |
| `AntiExploitService`| Counts rejected requests and removes clients that flood invalid requests (never in Studio). |
| `DevService`        | Test commands, Studio or allow-listed users only. |

Services talk through direct calls (downward) and `Core/Events` signals (sideways). For example, BuildingService fires `Events.Collected` and QuestService counts it. There are no circular requires.

## Data flow: collecting a harvest

```
client  ProximityPrompt "Collect" → Remotes.Collect:InvokeServer("farm1")
server  Net: loaded? rate ok? arg is a valid id?
        BuildingService.collect: farm1 is in *this player's* profile? player within 28 studs?
        ProductionService.Flush → storage brought up to date from elapsed time
        EconomyService.Add(Moonpetal, floor(stored)) → limited by silo capacity
        Events.Collected → QuestService progress
        StateService.Push("Buildings", "Wallet") → coalesced State events to the client
client  StateController updates sections → HUD, bubbles and panels re-render
```

## Saving

- **Store.** DataStore `CreatureEmpire_Profiles_v1`, key `Player_<userId>`. The record is `{ Data, Meta = { Lock = { JobId, Time }, SaveCount, LastSave } }`.
- **Load.**
  - `UpdateAsync` takes the lock unless another server refreshed it within 240 s.
  - If the lock is held, load retries 6 times, 5 s apart, then kicks the player with "still being saved". Nothing is written.
  - DataStore errors are retried 5 times with backoff of 1, 2, 4 and 8 s. If they still fail, the player is kicked with "nothing was changed".
  - A profile from a newer schema version is refused.
- **Save.** The save only writes if this server still owns the lock. On `LockLost` the server stops saving that profile and removes the player.
- **Autosave.** Every 60 s if the profile changed, and at least every 120 s to refresh the lock. Also on leave (which releases the lock) and in `BindToClose` (all players in parallel, 25 s budget).
- **What's saved.** Only durable state: balances, creatures, building records, quests, collection, settings and stats. Animations, buffs and fractional work cycles are never saved.
- **Studio without API access.** A default profile is used with `CanSave = false`, and the HUD shows it. It can never write.
- **Schema.** `Core/Schema.luau` holds the defaults, `Migrations[n]` (vN → vN+1) and `Sanitize`, which repairs a malformed profile instead of discarding it.

## Security model

Every client → server call goes through `Core/Net.Handle`, which checks in this order:

1. The profile is loaded.
2. The per-remote token-bucket rate limit allows it.
3. The argument types and shapes are valid (ids are short alphanumeric strings, numbers are finite integers, no extra arguments).
4. The handler runs inside `pcall`.

Handlers then check ownership (the target must be in the caller's profile), distance for physical actions (collect, sell), state (slots, limits, cooldowns, prerequisites) and price (from config, never from the client).

Visitors can walk onto any plot. Their client only creates "Inspect" prompts there, and if they send requests anyway, the server rejects anything that isn't in their own profile.

## Production maths

Per creature at a production building:

```
cycleTime = levelCycleTime / ((WorkSpeed/10) × speedBonus)
perCycle  = levelYieldPerCycle × recipeOutputs × (Yield/10) × jobAffinity(stage) × yieldBonus
rate      = perCycle / cycleTime            (per second; the building's rate is the sum, until storage is full)
```

Bonuses follow `EconomyConfig.BonusRules`:

- Bonuses in the same category **add** and are capped per category: Level, Stage, Passive, Empire, Ability, Synergy, Boost.
- Categories **multiply** with each other.
- The total is capped at `MaxMultiplier` (6×).

New sources of bonuses (synergies, research, boosts) must use one of these categories, which keeps them from stacking without limit.

Costs follow `Cost(level) = Base × Growth^(level−1)`, rounded to two significant figures. Each building has its own growth rate.

## Extending

- **New species.** Add a `species({...})` entry in `CreatureConfig.luau`. Set `Phase` to when it becomes obtainable. Its `Appearance.Features` pick parts from `client/Visuals/CreatureModels.luau`; add a feature builder there for new body parts. Add its sound keys to `AssetConfig`.
- **New building.** Add it to `BuildingConfig.luau` (levels, footprint, job, recipe). Add a model builder to `server/World/BuildingModels.luau`, otherwise a labelled placeholder is used. Add it to the Empire Core's `BuildingLimits` if it's placeable.
- **New recipe or resource.** Add entries to `RecipeConfig` and `ResourceConfig`. Inputs are consumed from the silo as the building works (`Production.Step`); outputs per cycle can be more than one unit.
- **New egg.** Add it to `EggConfig` (cost, loot weights, pity rarity and limit). The Hatchery panel lists it and publishes its odds automatically.
- **New quest step.** Add a step to `QuestConfig.Tutorial` with an existing `Kind`, or add an evaluator in `QuestService.Evaluators` plus a counter hook.
- **New remote.** Add its name in `Shared/Remotes.luau` and register it with `Net.Handle(name, { Rate, Args }, handler)`.
- **Schema change.** Bump `Schema.CURRENT_VERSION`, add `Migrations[old]`, update `Default` and `Sanitize`, and add a migration test in `tests/specs/Data.spec.luau`.

## Performance notes

- **Server.** One production loop (1 Hz) and one state flush loop (about 7 Hz, coalesced). There are no per-creature or per-building scripts, and no physics.
- **Creatures.** Client-rendered. Within 110 studs they update every frame; up to 260 studs every 4th frame without particles; beyond that they have no model and only their logic ticks. There is a hard cap of 60 rendered creatures.
- **Ambient motion** (windmills, crystals) runs at 30 Hz within 220 studs, and is off with Reduced Motion or VFX Off.
- **Buildings** are anchored static parts. Upgrades rebuild one model.
- **Bandwidth.** State is sent per section only when it changes. Storage is re-synced every 5 s while producing, and clients extrapolate in between for display.
