# Testing and debugging

## What has been verified, and how

| Check | Tool | Status |
| ----- | ---- | ------ |
| Project builds into a place file | `rojo build` | ✔ |
| Type checking of all code against the Roblox API definitions | `luau-lsp analyze` with a Rojo sourcemap | ✔ no errors |
| Formatting | `stylua --check src tests` | ✔ |
| Logic tests (63): formulas, bonus caps, grid placement, production rates, slots, XP, rate limiting, schema defaults, migrations, repair, session locking (live and abandoned locks, lock loss, transient and persistent errors, double transforms, unrecognised data), profile size, config integrity, economy pacing | Lune (`lune run tests/run`) | ✔ all pass |
| Running inside Roblox (server, client, UI, rendering, DataStore) | Roblox Studio | **Not done yet.** No Studio was available where this was built. Use the manual checklist below. |

Selene is configured (`selene.toml`) but wasn't run, because generating its Roblox standard library needs a download that wasn't reachable. Run `selene generate-roblox-std && selene src` locally.

## Running the automated checks

```bash
cd creature-empire
lune run tests/run                     # logic tests (Lune 0.8.x)
rojo sourcemap -o sourcemap.json
luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src
stylua --check src tests
```

`globalTypes.d.luau` comes from the [luau-lsp repository](https://github.com/JohnnyMorganz/luau-lsp) (`scripts/globalTypes.None.d.luau`).

`tests/harness.luau` loads real game modules outside Roblox by mapping `script.Parent`, `game:GetService(...)` and `WaitForChild` onto the source folders. Only modules without engine side effects can be loaded this way: everything in `shared/`, plus `server/Core`.

## Manual test checklist (Studio)

Run these in Studio with **Enable Studio Access to API Services** turned on unless stated. Use *Test → Clients and Servers* with 2 players for the multiplayer rows.

### First-time player
- [ ] Join with a fresh profile (*Settings → Developer → Reset profile*, then rejoin). The loading veil disappears and the starter choice appears and can't be closed.
- [ ] Choose each starter on different test accounts. The reveal plays and the creature appears in the habitat. Quest 2 points a trail at the farm.
- [ ] Assign the creature from the farm's **Manage** prompt. It walks to the farm and works. Harvest popups appear and the storage bubble fills.
- [ ] Collect at the farm (**E**). The wallet increases and the silo gauge rises.
- [ ] Sell at the Trading Post. Gold increases. The quest gives the second starter and its reveal plays.
- [ ] Upgrade the farm to level 2. The model changes (second bed) and slots become 2/2. Assign the second creature.
- [ ] Use an ability from the creature bar. The effect plays, the cooldown counts down, and it survives a rejoin.
- [ ] Place a second farm: the preview is green or red, rotation works, and you can't place on the path or another building. Gold is spent and the third starter is granted.
- [ ] Upgrade the silo and then the core. The core gate message shows when a farm is ahead of the core. The quest line finishes.

### Production and storage
- [ ] When storage is full, production stops, the creature shows "Waiting: storage is full", and no XP is gained.
- [ ] When the silo is full, collecting leaves the remainder in the farm with a clear message.
- [ ] Offline: *Developer → Away 60 min*, leave, rejoin. A "While you were away" toast appears and the amounts match about 50% × rate × 3600, capped by storage.
- [ ] Creature levels up after enough cycles. A toast appears and the rate rises slightly.

### Saving and data safety
- [ ] Earn gold, leave, rejoin. Everything persists: creatures, assignments, buildings and positions, levels, quests, settings, cooldowns.
- [ ] Join the same account in two Studio servers at once (or join a live server while another is still saving). The second server waits and then either loads or kicks with "still being saved". The data isn't lost.
- [ ] Turn API access **off**. The HUD says progress isn't saved and the game is playable. Turn it back on: the old data is unchanged.
- [ ] Stop the server with players inside (BindToClose). Data is saved.
- [ ] Corrupt a saved profile on purpose (for example, use a DataStore editor to set `Data.Currencies.Gold` to a negative number and delete `Data.Buildings.core`), then rejoin. The profile is repaired (Gold 0, core restored) and the output log shows a `Profile repaired` line.

### Multiplayer and permissions
- [ ] Each player gets their own plot. Signs show the owner names.
- [ ] Walk onto another player's plot. You only see **Inspect empire** prompts, and the inspect view is read-only.
- [ ] From the visitor's client command bar, invoke `Collect` / `UpgradeBuilding` / `AssignCreature` with the owner's building ids. All are refused.
- [ ] Creatures on other plots render and animate. Far plots show no creature models (performance tiers).

### Invalid and hostile requests
- [ ] Spam `Collect` from the command bar: "Slow down" after the burst. AntiExploit logs rejected requests and, outside Studio, kicks after 120 in a minute.
- [ ] Send wrong types (`PlaceBuilding("MoonpetalFarm", 1.5, "x", 9)`). Rejected with "Invalid request." and nothing changes.
- [ ] `Sell("Moonpetal", -5)`, `Sell("Gold", 10)` and `UseAbility` on another player's creature id are all refused.

### Input and accessibility
- [ ] Keyboard shortcuts C / B / J / P toggle windows and don't fire while typing in chat.
- [ ] Gamepad: D-pad opens windows, B closes, selection highlight is visible, and placement works with Y / A / B.
- [ ] Touch (device emulator, phone sizes): HUD readable, windows fit, tap-to-place works.
- [ ] Settings: volumes apply, VFX Off removes particles and motion, Reduced Motion stops bobbing and popping, Fast reveals skips the build-up.
- [ ] Rarity is always shown with a glyph and a word, not only colour.

### Performance
- [ ] 6 players × 3 creatures × 6 farms: server heartbeat stays near 60 in the MicroProfiler. `ProductionService` and `StateService` each take well under 1 ms per tick.
- [ ] Client: frame time with every plot in view. The creature model count stays at or below 60.

## Debugging guide

- **Logs** are structured: `[CE][Tag] message key=value`. Useful tags:
  - `Data`: load, save, lock and repair events.
  - `Economy`: every change, with *Developer → Verbose logs* on.
  - `Building`, `Creature`, `Quest`: player actions.
  - `AntiExploit`: rejected requests.
  - `Net`: handler errors, with the remote name and user.
- **"Your empire is still loading"** on every action: the profile never loaded. Check `Data` logs for `Load failed` or `locked`.
- **Kicked with "still being saved"**: another server holds the session lock. It clears when that server saves, or 240 s after it stops refreshing (a crash).
- **Nothing produces**:
  - Check the farm panel. "Not producing" means no assigned creature has the job affinity.
  - "Storage is full" means you need to collect.
  - `ProductionService` warnings show tick errors.
- **UI doesn't update**: check that the client receives `State` events (Developer Console → Network) and that `StateService` has no `failed` warnings.
- **Inspect saved data**: in the Studio command bar,
  `print(game:GetService("HttpService"):JSONEncode(game:GetService("DataStoreService"):GetDataStore("CreatureEmpire_Profiles_v1"):GetAsync("Player_<id>")))`

## Release checklist

- [ ] All automated checks pass. The manual checklist has been run on desktop, phone emulator and gamepad.
- [ ] Max Players = 6. API access on. DataStore name is the intended production name.
- [ ] `GameConfig.DeveloperUserIds` is empty (or only lists trusted developers).
- [ ] Every asset in [ASSETS.md](ASSETS.md) is either imported with a verified id or knowingly left silent or placeholder.
- [ ] No monetization is live until product ids are configured and tested (Phase 6).
