# roblox-sim

A Roblox simulator game, managed as code with [Rojo](https://rojo.space).

## Gameplay loop

1. **Train**: click the TRAIN button (or press **E**) to gain Power.
2. **Sell**: step on the green **SELL** pad to turn your Power into Coins.
3. **Upgrade**: spend Coins in the shop:
   - **Strength**: more Power per click
   - **Backpack**: hold more Power before you have to sell
   - **Sell Value**: more Coins for each Power you sell

Progress saves automatically with DataStores.

## Quick start (no setup)

Download **`roblox-sim.rbxl`** and double-click it (or *File → Open from File* in Roblox Studio),
then press **Play**. Rebuild it after code changes with `rojo build -o roblox-sim.rbxl`.

## Getting started (live sync while developing)

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder (installs Rojo, Selene, StyLua).
2. In Roblox Studio, install the **Rojo** plugin (from the Creator Store, or run `rojo plugin install`).
3. Open a new **Baseplate** place in Studio.
4. In this folder run:
   ```sh
   rojo serve
   ```
5. In Studio, open the Rojo plugin and click **Connect**. Your code now syncs live.
6. Press **Play** to test.

> To test saving in Studio: *Game Settings → Security → Enable Studio Access to API Services*
> (the place must be published first). Without it, the game still runs but won't save.

To build a place file without Studio: `rojo build -o game.rbxlx`

## Project layout

```
src/
  shared/              -> ReplicatedStorage.Shared   (used by server and client)
    Config.luau          all tunable numbers: upgrade costs, capacity formulas, etc.
    Remotes.luau         RemoteEvents/RemoteFunctions
  server/              -> ServerScriptService.Server
    Main.server.luau     starts the services
    Services/
      DataService.luau   load/save player data (DataStores)
      GameService.luau   train / sell / upgrade logic + leaderstats
      WorldService.luau  builds the Sell pad
  client/              -> StarterPlayer.StarterPlayerScripts.Client
    Main.client.luau     HUD: stats, Train button, upgrade shop
```

**Balancing the game:** most changes happen in `src/shared/Config.luau`.

**Adding an upgrade:** add it to `Config.Upgrades`, `Config.UpgradeOrder` and
`Config.DefaultData.Upgrades`, then use its level in `GameService`. Existing players
pick up the new default automatically.

The server checks every action, so players can't cheat by editing their own client.
