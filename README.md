# Dungeon Delvers

A Roblox dungeon crawler (inspired by games like Dungeon Quest), managed as code with [Rojo](https://rojo.space).

## How to play

1. **Pick a dungeon:** stand on a glowing portal pad in the lobby. After a 10 second
   countdown, everyone on the pad (up to 4 players) is sent in together.
2. **Clear the rooms:** your sword is always out. **Click** to swing. Kill every enemy in a
   room to open the door to the next one.
3. **Use abilities:** **Q** = Whirlwind (hits everything around you), **E** = Heal.
4. **Beat the boss:** watch for the **red circle** on the floor and get out before it slams!
5. **Get loot:** winning gives XP, Gold, and a random weapon. Equip weapons from the
   **Weapons** button on the left.

If your whole party dies, the run fails and you're back in the lobby.

| Dungeon         | Level | Enemies               | Boss               |
| --------------- | ----- | --------------------- | ------------------ |
| Crypt of Bones  | 1+    | Skeletons, Zombies    | The Bone King      |
| Sunken Temple   | 5+    | Mummies, Scarabs      | The Cursed Pharaoh |
| Frozen Keep     | 10+   | Yetis, Frost Wraiths  | The Frost Lord     |

Progress (level, gold, weapons) saves automatically with DataStores.

## Quick start (no setup)

Download **`dungeon-delvers.rbxl`** and double-click it (or *File → Open from File* in Roblox Studio),
then press **Play**. To test parties, use *Test → Clients and Servers* with 2+ players.

> To keep progress between test sessions in Studio: publish the place, then turn on
> *Game Settings → Security → Enable Studio Access to API Services*.

Rebuild the file after code changes with `rojo build -o dungeon-delvers.rbxl`.

## Developing with live sync

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder.
2. Install the **Rojo** plugin in Studio (`rojo plugin install`).
3. Run `rojo serve`, then click **Connect** in the Rojo plugin.

## Project layout

```
src/
  shared/                 -> ReplicatedStorage.Shared
    Config.luau             leveling, health/damage scaling, abilities, party size
    Weapons.luau            every weapon (damage, speed, range, look, rarity)
    Enemies.luau            every enemy and boss
    Dungeons.luau           dungeons: rooms, boss, rewards, loot table, colors
    Remotes.luau            RemoteEvents/RemoteFunctions
  server/                 -> ServerScriptService.Server
    Main.server.luau        starts the services
    Services/
      DataService.luau      load/save player data
      PlayerService.luau    level, XP, gold, inventory, leaderstats
      CombatService.luau    swords, swinging, abilities
      EnemyService.luau     builds enemies, AI, boss slam attack
      DungeonService.luau   lobby portals, parties, dungeon building and runs
  client/                 -> StarterPlayer.StarterPlayerScripts.Client
    Main.client.luau        HUD: health/XP bars, abilities, weapons menu, messages
```

### Adding content

- **New weapon:** add it to `Weapons.Defs` and `Weapons.Order`, then put it in a dungeon's `Loot` table.
- **New enemy:** add it to `Enemies.luau` (add a `Boss` table to make it a boss).
- **New dungeon:** add it to `Dungeons.Defs` and `Dungeons.Order`. A new portal appears in the lobby automatically.

All maps and enemies are built from code, so no models or assets need importing.
The server checks every action, so players can't cheat by editing their own client.
