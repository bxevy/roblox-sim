# Dungeon Delvers

A Roblox dungeon crawler (inspired by games like Dungeon Quest), managed as code with [Rojo](https://rojo.space).

## The town

You spawn in a walled medieval town: stone walls and towers, a gatehouse, the castle keep looming
behind the dungeon portals, timber-framed houses, **The Rusty Tankard** tavern, a blacksmith's forge,
a market, a fountain, and lamp-lit streets at golden hour. The notice board next to the spawn has
quick tips. It's all built from code in `HubService.luau`, so you can tweak it there or replace
pieces with hand-built models in Studio.

## How to play

1. **Pick a class** when you first join (change it any time in the lobby with the **Class** button):
   | Class   | Weapon | Strengths                         | Q          | E              |
   | ------- | ------ | --------------------------------- | ---------- | -------------- |
   | Warrior | Sword  | +30% health, +10% defense         | Whirlwind  | Shield Wall    |
   | Mage    | Staff  | +25% damage, ranged splash magic  | Fireball   | Healing Circle (heals the party) |
   | Ranger  | Bow    | +15% speed, longest range         | Volley     | Swift Step     |
2. **Buy potions** at the potion shop in the lobby (press **F** at the counter). Drink them with **1-5**.
3. **Pick a dungeon & difficulty:** stand on a portal pad and choose a difficulty from the panel.
   After a 10 second countdown, everyone on the pad (up to 4 players) goes in together.
4. **Fight:** **click** to attack toward your mouse. Kill every enemy in a room to open the next door.
   Watch for the boss's **red circle** and get out before it slams!
5. **Loot:** winning gives XP, Gold, and an item: a weapon for your class or a piece of armor.
   Equip gear with the **Gear** button (or **G**).

### Difficulties

Each dungeon has Easy / Normal / Hard / Nightmare. Harder difficulties have tougher enemies,
more XP and Gold, and drop **higher-tier loot**.

| Dungeon        | Easy | Normal | Hard | Nightmare | Loot tiers (Easy to Nightmare) |
| -------------- | ---- | ------ | ---- | --------- | -------------------------------- |
| Crypt of Bones | Lv 1  | Lv 3  | Lv 6  | Lv 9  | T1-2, T2-3, T3-4, T4-5 |
| Sunken Temple  | Lv 10 | Lv 13 | Lv 16 | Lv 19 | T3-4, T4-5, T5-6, T6-7 |
| Frozen Keep    | Lv 20 | Lv 24 | Lv 28 | Lv 32 | T5-6, T6-7, T7-8, T7-8 |

### Gear

- **24 weapons:** 8 swords, 8 staffs, 8 bows across tiers 1-8 (Common to Legendary). Higher tiers
  have special effects: **Burn** (damage over time), **Frost** (slows enemies) or **Lifesteal**.
- **8 armor sets** that work for every class, adding health and damage reduction, and show on your character.

If your whole party dies, the run fails and you're back in the lobby. Progress saves automatically.

### Studio test commands

When playing in Roblox Studio (never in a live game), type in chat:
`/level 20`, `/gold 5000`, `/give Dragonfang`, `/giveall`.

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
    Config.luau             leveling, classes, abilities, buffs, difficulties, potions
    Items.luau              every weapon and armor (tiers, stats, effects, colors)
    Enemies.luau            every enemy and boss
    Dungeons.luau           dungeons: rooms, boss, rewards, unlock levels + loot per difficulty
    Remotes.luau            RemoteEvents/RemoteFunctions
  server/                 -> ServerScriptService.Server
    Main.server.luau        starts the services
    Build.luau              helpers for building scenery from parts
    Services/
      DataService.luau      load/save player data
      PlayerService.luau    level, XP, gold, class, items, buffs, stats
      CombatService.luau    weapon/armor models, attacks, effects, class abilities
      EnemyService.luau     builds enemies, AI, boss slam attack
      DungeonService.luau   lobby portals, difficulty picking, parties, dungeon runs, loot
      ShopService.luau      potion shop stall, buying and drinking potions
      HubService.luau       builds the medieval town and sets the lighting
      DevService.luau       Studio-only chat commands for testing
  client/                 -> StarterPlayer.StarterPlayerScripts.Client
    Main.client.luau        input (attack, Q/E, 1-5, G) and wiring
    UI/                     Hud, Inventory, Shop, ClassPicker, PortalPanel
```

### Adding content

- **New weapon or armor:** add a line to `WEAPON_LIST` / `ARMOR_LIST` in `Items.luau`. It drops
  automatically from any difficulty whose loot includes its tier.
- **New potion:** add it to `Config.Potions` and `Config.PotionOrder`.
- **New class:** add it to `Config.Classes` / `Config.ClassOrder` with a new weapon type and abilities
  (abilities are coded in `CombatService`).
- **New enemy:** add it to `Enemies.luau` (add a `Boss` table to make it a boss).
- **New dungeon:** add it to `Dungeons.Defs` and `Dungeons.Order` with its 4 difficulties. A new portal appears in the lobby automatically.

All maps and enemies are built from code, so no models or assets need importing.
The server checks every action, so players can't cheat by editing their own client.
