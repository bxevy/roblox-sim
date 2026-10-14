# Testing and debugging

## What has been verified, and how

| Check | Tool | Status |
| ----- | ---- | ------ |
| Project builds into a place file | `rojo build` | ✔ |
| Type checking of all code against the Roblox API definitions | `luau-lsp analyze` with a Rojo sourcemap | ✔ no errors |
| Formatting | `stylua --check src tests` | ✔ |
| Logic tests (93): formulas, bonus caps, grid placement, production rates, slots, XP, rate limiting, schema defaults, migrations, repair, session locking (live and abandoned locks, lock loss, transient and persistent errors, double transforms, unrecognised data), profile size, config integrity, economy pacing, v1→v2 migration, input recipes and starvation, hatching odds/pity (incl. 100k seeded rolls), evolution requirements and bonuses, expansion bounds, content reachability | Lune (`lune run tests/run`) | ✔ all pass |
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
- [ ] Sell at the Trading Post in the plaza (there is no Trading Post on plots any more). Gold increases. The quest gives the second starter and its reveal plays.
- [ ] Upgrade the farm to level 2. The model changes (second bed) and slots become 2/2. Assign the second creature.
- [ ] Use an ability from the creature bar. The effect plays, the cooldown counts down, and it survives a rejoin.
- [ ] Place a second farm: the preview is green or red, rotation works, and you can't place on the path or another building. Gold is spent and the third starter is granted.
- [ ] Upgrade the silo and then the core. The core gate message shows when a farm is ahead of the core. The quest line finishes.

### Phase 2: hatching, crystals, evolution, land
- [ ] Open the Hatchery nest in the plaza. Each egg lists every creature with its exact % and rarity word. The odds add up to 100%.
- [ ] Hatch a Meadow Egg. Gold is spent and an egg-coloured reveal plays. Pity goes up by 1, or resets on a Rare.
- [ ] *Developer → +1,000 gold* repeatedly and hatch 14 Meadow Eggs. If no Rare appeared, the panel says the next hatch is guaranteed, and it is.
- [ ] Fill the habitat (6). Hatch is disabled with "Habitat full". Upgrading the habitat makes room.
- [ ] Core tier 2 → build a Crystal Mine, assign Pebblit, collect Raw Crystal. The bubble and popups use the crystal colour.
- [ ] Build a Crystal Smelter with Cindercub. Raw Crystal drains from the silo (HUD pill) and Refined Crystal accumulates. With no raw crystal left, the panel says "Paused" and the creature shows "Waiting: needs materials".
- [ ] Essence Condenser (tier 3) with Wisplet or Puddlefin: uses Refined Crystal and Moonpetals and makes Essence (a currency, so collecting has no silo limit).
- [ ] Evolution: *Developer → +5 levels* and *+100 essence*, build the Evolution Chamber. The Creatures window checklist turns green, Evolve plays the evolution reveal, the creature grows, gains new features, and the job rate rises (about ×1.52 for Sproutling).
- [ ] Buy West Meadow (tier 2, 1,500 gold) at the Empire Core. The fence moves out and buildings can be placed on the new land, including straddling the old edge.
- [ ] Move a farm with *Move this building*. Its workers follow and production carries on.
- [ ] Rejoin: pity, expansions, evolutions, job cycles and moved buildings all persist.
- [ ] Load an account saved by the Phase 1 build. It migrates to v2, its creatures keep their farming work as Farmer cycles, and nothing is lost.

### Phase 3: Emberfall Basin, expeditions, guardian
- [ ] Below core tier 2, the plaza gate refuses travel with a clear message. At tier 2 the gate (and the Map's Travel button) puts you at the basin's arrival point, on solid ground.
- [ ] In the basin: the sky turns ash-orange, ash drifts, and the HUD shows a heat bar and the next eruption time. *Return home* works from anywhere.
- [ ] Heat rises slowly, quickly on lava, and jumps at an erupting vent (a red flash). Vents glow yellow before they fire. Standing in a blue pool cools you. At 100% you're carried back to the gate with a message and the heat resets to 30%.
- [ ] Take Cindercub as a companion: it follows you through the gate, and heat rises about half as fast.
- [ ] Gather from an Emberstone deposit (hold E). Emberstone appears in the silo. The deposit dims and can't be gathered again until its timer ends. Gathering from 20+ studs away (command bar) is refused.
- [ ] Find all 5 landmarks. Each gives a reward toast once, and the Map journal ticks it off. The grotto shows as ??? until found.
- [ ] *Developer → +50 emberstone*, craft an Ember Lure at the Trading Post. Throw it at a wild creature: the window shows the chance first, the creature leaves either way, and a success plays the reveal.
- [ ] Wait for an eruption (the HUD timer counts down): the mood darkens and a Pyrewing appears near the overlook.
- [ ] Build an Expedition Portal. Pick a team, approach and supplies: the chance changes live. Launch: the creatures leave their jobs and vanish from the plot. *Developer → Finish expeditions*, claim: the report lists events and loot, creatures return and rest (or not, with Rations).
- [ ] Rejoin with an expedition running: it's still running, and the result after claiming matches what it would have been (seeded).
- [ ] Guardian: walk into the caldera with a companion. The combat bar appears. 1/2 attack, slam circles fill before impact, getting hit adds heat. With two players the guardian has more health and both get rewards. The first win grants a Magmaul. She returns after 3 minutes.
- [ ] Load a Phase 2 save. It migrates to v3 without losing anything.

### Phase 4: research, synergies, couriers, mutations, Ascension
- [ ] Research Station: assign Wisplet. Moonpetals drain from the silo, Insight accumulates, and collecting adds Insight to the wallet (HUD pill appears).
- [ ] Research Fertile Soil: Insight and gold are spent, and the farm rate rises by about 10%. Sharp Picks is locked until then. Rejoin: research persists.
- [ ] Synergy: put Sproutling and Cindercub on one farm (level 2). The panel shows ✔ Sun and Soil and the rate rises. Remove one and it switches off.
- [ ] Build menu: Courier Post says "Research Courier Routes first" until researched. Build it, assign Cogling: every ~5 s stored harvests move from the fullest building to the silo, and quest "Collect" steps count them. With the silo full the panel warns and nothing is lost.
- [ ] Gearhound's Fetch carries up to 40 items at once from anywhere; with nothing stored it refuses and keeps its cooldown.
- [ ] Hatch Arcane Eggs (*Developer → +100 Insight*, *+100 essence*). The odds add up to 100 and the mutation odds are listed. A mutated hatch shows a MUTATION chip in the reveal and a recoloured, sparkling model.
- [ ] Ascension: *Developer → Core tier 5*. The Empire Core panel shows the payout. The window lists resets/stays, needs a second confirm, and is refused while an expedition is away. After ascending: plot back to the starting layout, fence back to the start, creatures in the habitat, shards and +10% yield applied, Titanicore granted the first time. Rejoin: all of it persists.
- [ ] Buy a perk with shards; the rank shows, the price rises, and it stops at max.
- [ ] Load a Phase 3 save: it migrates to v4 and its lifetime gold counts as this run's gold.

### Phase 5: multiplayer (Studio → Test → Clients and Servers, 2–3 players)
- [ ] Players window (U): lists the others. Visit teleports to their plot entrance.
- [ ] Trade: player A invites B, and B sees an Accept/Decline card that disappears after 30 s. Both windows open.
  - [ ] Add creatures and lures (there's no gold or material field). Both sides update live, and every change clears both Ready ticks.
  - [ ] Ready on both sides: a 3 s countdown runs, and editing during it cancels.
  - [ ] After the swap, creatures appear on the other plot, journals update, and the lures moved exactly once.
  - [ ] Pressing C, B or U during a trade doesn't open other windows, and the ✕ cancels the trade.
- [ ] Trade refusals:
  - [ ] Starter, quest and companion creatures show "Can't".
  - [ ] A full habitat on the receiver refuses with a message.
  - [ ] Closing the window or leaving cancels, and nothing moves.
- [ ] Collaborators: A makes B a helper. B sees "Collect for owner" on A's farms, and the harvest lands in A's silo with a thank-you toast. Remove B: the prompts disappear. A visitor calling `CollectFor` from the command bar is refused.
- [ ] Cheer: at another player's Empire Core, the owner gets a toast and +10% speed on their buildings (the panel shows the buff).
  - [ ] Cheering again within 10 minutes is refused.
  - [ ] A 4th cheerer is refused while 3 cheers are active.
- [ ] World events (*Developer → Event: …*):
  - [ ] Golden Hour: production rates rise by 25% for everyone, and the HUD shows a timer.
  - [ ] Bloom: collecting Moonpetals moves the shared bar. Reaching the goal rewards helpers, and Elderbark arrives on the first win.
  - [ ] Ember Rift: the portal offers the rift (no slot used), and the team count rises as players join.
  - [ ] Ember Rift results: when the rift closes, everyone is told, and claimed results include the party bonus.
- [ ] Abilities: Rootwall (Elderbark companion) stops heat for you and nearby allies, and Veil (Shadeling) stops heat for you. Night Howl near the Matriarch raises damage numbers. Fold shortens running expeditions.
- [ ] Leaderboards:
  - [ ] Published game: the plaza board and the Rankings window (L) fill within about 2 minutes.
  - [ ] Studio without API access: the board shows the "needs DataStore access" message and nothing errors.
- [ ] Load a Phase 4 save: it migrates to v5.

### Phase 6: release features
- [ ] Pathfinding: place a building between the habitat and a farm. The assigned creature walks around it, not through it. Move the building away and the route updates.
- [ ] Rename a creature: the new name shows on its tag, in the Creatures window and in trades. A blocked word is refused with a message, and a blank name restores the species name.
- [ ] Shop (K):
  - [ ] With ids at 0, both items show "Coming soon".
  - [ ] With test ids configured, buying the boost adds +25% speed (shown in building panels) and survives a rejoin.
  - [ ] Buying again adds the full 30 minutes. With more than 1h30 left, the button says "Boost is full".
  - [ ] The Supporter pass shows ★ on the plot sign and a sparkle on your companion.
- [ ] Receipts: in Studio, buy the product, then stop the server before it saves. On the next join, Roblox retries the purchase and it's granted exactly once.
- [ ] Imported model: a model in Assets › Creatures replaces the species on plots, in portraits and in reveals, and stands on the ground. `Facing` and `HeightOffset` work. A rigged model with animation ids plays Idle, Walk and Work.
- [ ] Thundermaw, Nocturnox and Abyssquid: *Developer → Grant* each one. Their abilities work, and Dark Gift makes the next hatch's mutation odds ×3, then resets.
- [ ] Load a Phase 5 save: it migrates to v6.
- [ ] Failure drill: with API access on, leave while the DataStore is throttled (or disconnect the network briefly). The log shows "Release save failed; retrying", rejoining the same server says "still being saved", and once the retry succeeds nothing is lost.
- [ ] Rename a creature to `<b>hi</b>`: refused. Trade a renamed creature: the card shows its species name too.

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
- [ ] Keyboard shortcuts C / B / J / P / G / M / U / L / K toggle windows and don't fire while typing in chat.
- [ ] Gamepad: D-pad opens windows, B closes, selection highlight is visible, and placement works with Y / A / B.
- [ ] Touch (device emulator, phone sizes): HUD readable, windows fit, tap-to-place works.
- [ ] Settings: volumes apply, VFX Off removes particles and motion, Reduced Motion stops bobbing and popping, Fast reveals skips the build-up.
- [ ] Rarity is always shown with a glyph and a word, not only colour.

### Performance
- [ ] 6 players × 3 creatures × 6 farms: server heartbeat stays near 60 in the MicroProfiler. `ProductionService` and `StateService` each take well under 1 ms per tick.
- [ ] Client: frame time with every plot in view. The creature model count stays at or below 60.

## Plaza and Spin Wheel (1.1)

- [ ] The plaza has the Trading Post, the Hatchery nest and the Spin Wheel, between the paths, clear of the travel gate and the leaderboard board. Plots have neither a Trading Post nor a Hatchery, and the Build menu doesn't offer a Hatchery.
- [ ] An old save that had a Hatchery loses it and gets 400 gold back.
- [ ] Walking up to each station shows its prompt (Sell & craft / Hatch eggs / Spin). Selling, crafting and hatching from far away are refused with a message naming the plaza.
- [ ] Spin Wheel: the window lists every prize with its % (they add up to 100%). The first spin is free; afterwards the button counts down 30:00 and the HUD card shows "Next free spin in …".
- [ ] The wheel stops on the prize the toast names. 2× Coins doubles the Trading Post prices shown and the gold received. 2× Luck adds a note in the Hatchery and raises the rare-or-better odds shown.
- [ ] *Developer*: winning the Black Dragon (try `SpinConfig` with its weight raised in Studio only) plays the reveal after the wheel stops, and other players get a toast.

## Habitats and backpack (1.2)

- [ ] A new plot has one habitat; the Creatures window shows "Habitats 0 / 5". The 6th pet you get goes to the backpack with a message, and doesn't appear on the plot.
- [ ] Build a second Creature Habitat (Build → Creature care, 1,500 gold): capacity becomes 10, and "Take out to a habitat" works for a backpack pet. Pets wander around both habitats.
- [ ] "Put in backpack" on a working pet stops its job and hides it; on your companion it stops following. A backpack pet can't be assigned, taken along, sent on an expedition or use its ability.
- [ ] An old save with a level-3 habitat gets the upgrade gold back and keeps 5 pets on the plot.

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
