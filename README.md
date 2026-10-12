# Dungeon Delvers

A Roblox dungeon crawler (inspired by games like Dungeon Quest), managed as code with [Rojo](https://rojo.space).

## The town

You spawn in a walled medieval town: stone walls and towers, a gatehouse, the castle keep looming
behind the dungeon portals, timber-framed houses, **The Rusty Tankard** tavern, a blacksmith's forge,
a market, a fountain, and lamp-lit streets at golden hour. Townsfolk wander the streets and chat,
guards watch the gate, and the notice board next to the spawn has quick tips.

Through the south gate are the **Training Grounds**: straw dummies that show your damage per
second, an archery & magic range, and a sparring ring. It's all built from code in `HubService.luau`, so you can tweak it there or replace
pieces with hand-built models in Studio.

## How to play

1. **Pick a class** when you first join (change it any time in the lobby with the **Class** button):
   | Class   | Weapon | Strengths                         | Q          | E              |
   | ------- | ------ | --------------------------------- | ---------- | -------------- |
   | Warrior | Sword  | +30% health, +10% defense         | Whirlwind  | Shield Wall    |
   | Mage    | Staff  | +25% damage, ranged splash magic  | Fireball   | Healing Circle (heals the party) |
   | Ranger  | Bow    | +15% speed, longest range         | Volley     | Swift Step     |
2. **Buy potions** at the potion shop in the lobby (press **F** at the counter). Drink them with **2-6**.
3. **Pick a dungeon & difficulty:** stand on a portal pad and choose a difficulty from the panel.
   After a 10 second countdown, everyone on the pad (up to 4 players) goes in together.
4. **Fight:** press **1** to draw / put away your weapon, **click** to attack toward your mouse.
   Hold **Shift** to sprint and press **C** to dodge (you're immune to damage mid-dodge); both use
   the yellow stamina bar. Kill every enemy in a room to open the next door.
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
- **Mythic: Voidlight Greatsword.** A 0.05% (1 in 2,000) bonus drop from any dungeon victory.
  The whole server is told when someone finds it. Change the odds in `Config.MythicDrop`.
- **10 armor sets**, each with 4 pieces (helmet, chestplate, leggings, boots) that work for every
  class. Each piece adds health and defense and has its own look and particle effects; wearing all
  4 pieces of one set gives a **set bonus** and an aura.

  | Set | Rarity | Where |
  | --- | --- | --- |
  | Squire's Leathers, Militia Chainmail | Common | Dungeon loot (tiers 1-2) |
  | Knight's Plate, Crusader's Plate | Rare | Dungeon loot (tiers 3-4) |
  | Royal Guard Regalia, Warlord's Bastion | Legendary | Dungeon loot (tiers 5-6) |
  | Paladin's Radiance, Abyssal Knight | Mythic | Dungeon loot (tiers 7-8) |
  | **Black Dragon**, **Shogun's Oath** | **Godly** | Crates only |

- **Crate Shrine** (west side of the plaza, press **F**): spend Gold on a Black Dragon or Shogun's
  crate for a chance at its Godly set (5% per crate), or Rare/Legendary/Mythic armor. Duplicates
  refund 25% of the price. Odds and prices are in `Config.Crates`.

If your whole party dies, the run fails and you're back in the lobby. Progress saves automatically.

### Leaderboards & stats

Lifetime stats are saved per player: enemies slain, dungeons cleared, bosses defeated, gold
earned, crates opened, deaths and minutes played. The **Hall of Heroes** boards by the south gate
show the global top 10 (all servers) for Highest Level, Enemies Slain, Dungeons Cleared and Gold
Earned. Press **T** for your own stats and the boards. (Global boards need a published place with
API access; otherwise they rank the players in the current server.)

### Dungeon themes

Each dungeon has its own look, lighting mood and music: the **Crypt** (coffins, skull shelves,
cobwebs, green mist), the **Sunken Temple** (gold-capped columns, jackal statues, sand, treasure),
and the **Frozen Keep** (glowing ice crystals, icicles, snowdrifts, falling snow).

### Admin menu

Admins see an **Admin Menu** button (or press **P**): **Give All Items**, max potions, gold, level,
heal, god mode, clear the current room, teleport to town / training, and give any item by id.
Chat commands work too: `/giveall`, `/level 20`, `/gold 5000`, `/give Dragonfang`.

Admins are: anyone testing in Studio, the game's owner (or rank 254+ in the owning group), and
any user ids added to `Config.AdminUserIds`. The server checks every admin action.

### Music & sounds

Sound effects use sounds built into Roblox. Music ids are in `Config.Audio.Music`; if a track
is silent, swap in any audio id from the Creator Store (Studio: *Toolbox > Audio*). There's a
**Music: On/Off** button in the top-right.

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
    DungeonDecor.luau       themed decorations for Crypt / Temple / Ice rooms
    ArmorVisuals.luau       builds every armor piece's look and effects on the character
    Sfx.luau                plays sound effects in the world
    Services/
      DataService.luau      load/save player data
      PlayerService.luau    level, XP, gold, class, items, buffs, stats
      CombatService.luau    weapon/armor models, attacks, effects, class abilities
      EnemyService.luau     builds enemies, AI, boss slam attack
      DungeonService.luau   lobby portals, difficulty picking, parties, dungeon runs, loot
      ShopService.luau      potion shop stall, buying and drinking potions
      HubService.luau       builds the medieval town and sets the lighting
      TrainingService.luau  training grounds: dummies, archery range, sparring ring
      TownsfolkService.luau villagers who walk around and talk, guards, shopkeepers
      MovementService.luau  stamina, sprint and dodge
      AdminService.luau     admin menu actions and chat commands
      CrateService.luau     Crate Shrine, crate odds and opening
      LeaderboardService.luau  lifetime stats -> global leaderboards (Hall of Heroes)
  client/                 -> StarterPlayer.StarterPlayerScripts.Client
    Main.client.luau        input (attack, 1, Q/E, 2-6, G, T, P) and wiring
    Controllers/            Movement (sprint/dodge), Audio (music + dungeon lighting)
    UI/                     Hud, Inventory, Shop, ClassPicker, PortalPanel, AdminPanel,
                            CrateWindow, StatsWindow
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
