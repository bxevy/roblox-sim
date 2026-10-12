# Dungeon Delvers

A Roblox dungeon crawler (inspired by games like Dungeon Quest), managed as code with [Rojo](https://rojo.space).

## The town

You spawn in a big walled medieval town: stone walls and towers, a gatehouse, the castle keep
looming over a marble **portal terrace** with all six dungeon portals, a bronze statue of **The
First Delver**, royal gardens with a pond and a glowing **mage tower**, a stained-glass **chapel**,
a **market square** with stalls and a well, a **windmill farm**, timber-framed houses with smoking
chimneys and flower boxes, **The Rusty Tankard** tavern, a blacksmith's forge, a fountain plaza,
and lamp-lit streets at golden hour. Townsfolk wander the streets and chat, guards watch the gate,
and the notice board next to the spawn has quick tips.

Through the south gate are the **Training Grounds**: straw dummies that show your damage per
second, an archery & magic range, and a sparring ring. It's all built from code in `HubService.luau`, so you can tweak it there or replace
pieces with hand-built models in Studio.

## How to play

1. **Roll a class** (your first roll is free; open the **Class** button to roll again for 2,500
   coins or Robux; a new roll replaces your class):
   | Class       | Weapon     | Rarity / odds    | Passive                                        | Q / E                            |
   | ----------- | ---------- | ---------------- | ---------------------------------------------- | -------------------------------- |
   | Warrior     | Sword      | Common 20%       | +30% health, +10% defense                      | Whirlwind / Shield Wall          |
   | Mage        | Staff      | Common 18%       | +25% damage, magic splashes                    | Fireball / Healing Circle        |
   | Ranger      | Bow        | Common 18%       | +15% speed, longest range                      | Volley / Swift Step              |
   | Healer      | Tome       | Rare 8%          | Hits heal the most hurt teammate               | Holy Nova / Divine Shield        |
   | Berserker   | Axe        | Rare 8%          | Rage: up to +40% damage as your health drops   | Bloodlust / Leap Smash           |
   | Paladin     | Greatsword | Rare 8%          | +15% defense, regenerate 1.5% health/second    | Consecration / Judgment          |
   | Assassin    | Daggers    | Epic 5%          | +20% speed, +15% crit                          | Shadow Strike / Vanish           |
   | Necromancer | Scythe     | Epic 5%          | Hits heal you for 8% of damage                 | Raise Dead / Soul Harvest        |
   | Dragoon     | Spear      | Epic 5%          | +25% melee reach, +10% speed                   | Dragon Dive / Wyvern Lance       |
   | Treasurer   | Mace       | Legendary 2.5%   | 10% better loot drops                          | Coin Barrage / Midas Touch       |
   | Ronin       | Katana     | Legendary 2.45%  | +10% crit, crits deal +50% damage              | Iaido / Thousand Cuts            |
   | **Seraph**  | Halberd    | **GODLY 0.05%**  | +50% health & damage, +20% defense, wings and a halo, heals allies on hit, better loot, and **revives once per life** | Heaven's Wrath / Ascension |

   Rolling the Godly Seraph is announced to the whole server.

   **Robux rolls:** create a Developer Product (Creator Dashboard > your experience > Monetization >
   Developer Products), then put its id in `Config.ClassRoll.RobuxProductId` and its price in
   `RobuxPriceLabel`. Purchases are recorded per receipt so a roll is never granted twice.
2. **Buy potions** at the potion shop in the lobby (press **F** at the counter). Drink them with **2-6**.
3. **Pick a dungeon & difficulty:** stand on a portal pad and choose a difficulty from the panel.
   After a 10 second countdown, everyone on the pad (up to 4 players) goes in together.
4. **Fight:** press **1** to draw / put away your weapon, **click** to attack toward your mouse.
   Keep clicking to chain your weapon's **combo** (the last hit is a big finisher), and press
   **R** for your weapon's own ability.
   Hold **Shift** to sprint and press **C** to dodge (you're immune to damage mid-dodge); both use
   the yellow stamina bar. Kill every enemy in a room to open the next door.
   Halfway through each dungeon a **mini-boss** blocks the way, and the last room holds the boss.
5. **Loot:** winning gives XP, Gold, and an item: a weapon for your class or a piece of armor.
   Equip gear with the **Gear** button (or **G**).

### Difficulties

Each dungeon has Easy / Normal / Hard / Nightmare. Harder difficulties have tougher enemies,
more XP and Gold, and drop **higher-tier loot**.

| Dungeon          | Easy  | Normal | Hard  | Nightmare | Loot tiers (Easy to Nightmare) |
| ---------------- | ----- | ------ | ----- | --------- | ------------------------------ |
| Crypt of Bones   | Lv 1  | Lv 3   | Lv 6  | Lv 9      | T1-2, T2-3, T3-4, T4-5          |
| Witchwood Hollow | Lv 5  | Lv 8   | Lv 11 | Lv 14     | T2-3, T3-4, T4-5, T5-6          |
| Sunken Temple    | Lv 12 | Lv 15  | Lv 18 | Lv 21     | T3-4, T4-5, T5-6, T6-7          |
| Frozen Keep      | Lv 22 | Lv 25  | Lv 28 | Lv 31     | T5-6, T6-7, T7-8, T7-8          |
| Infernal Forge   | Lv 33 | Lv 36  | Lv 39 | Lv 42     | T6-7, T7-8, T7-8, T8            |
| Abyssal Rift     | Lv 40 | Lv 44  | Lv 47 | Lv 50     | T7-8, T8, T8, T8 (3x Mythic chance) |

Every dungeon has 6 rooms of enemies (melee, fast beasts, and **ranged casters whose shots you can
sidestep**), a **mini-boss** in room 4, and a boss.

### Boss mechanics

Bosses don't just hit you: they rotate through telegraphed attacks. **Red** on the floor means
danger, **green** means safe, and the filling circle/lane shows when it lands.

- **Slam** - a red circle around the boss. **Barrage** - a circle under every player: keep moving.
- **Meteors** - circles rain across the arena. **Charge** - a lane toward a player, then the boss rushes down it.
- **Cross** - beams in a + or x from the boss: stand between them. **Donut** - everything far away gets hit: get close.
- **Wave** - a ring expands from the boss: **dodge [C] through it** (dodging makes you immune).
- **Phases** at health thresholds: **summon** adds, **shield** themselves until you destroy their
  totems (Hex Totems, Canopic Jars, Ice Crystals, Flame Braziers, Void Rifts), and **enrage**
  (faster, harder hits, quicker mechanics).

A boss health bar shows at the top of the screen (blue while shielded, orange when enraged).
Bosses: The Bone King, The Hag Queen, The Cursed Pharaoh, The Frost Lord, Infernus the Molten
King, and The Void Emperor. Each boss and mini-boss is defined in `shared/Enemies.luau`, so you
can mix and tune mechanics there.

### Gear

- **96 weapons:** 8 for each class (swords, staffs, bows, tomes, axes, greatswords, daggers,
  scythes, spears, maces, katanas and halberds) across tiers 1-8
  (Common to Legendary). Higher tiers have special effects: **Burn** (damage over time), **Frost**
  (slows enemies) or **Lifesteal**. Every weapon has:
  - **its own design and VFX** (blade shape, guard, head, glowing runes, particle aura, light, and a
    swing trail), built from parts in `WeaponModels.luau` - no meshes to upload;
  - **its own ability on R** (25 kinds: cyclones, meteors, chain lightning, blinks, summoned blades,
    healing zones, coin bombs...) with its own cooldown, in `WeaponSkills.luau`;
  - **a combo style** (13 of them, e.g. *Blademaster*: slash, slash, spin; *Marksman*: shot, shot,
    triple shot; *Juggernaut*: overhead, backswing, ground pound). Each step has its own hit shape,
    damage and **animation**.
  - Animations are code-driven (they bend the character's joints), so they need no uploaded
    animation assets and everyone in the server sees them. Combos and animations live in
    `shared/WeaponMoves.luau`. Assassins also hold a second dagger in their left hand.
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

### Quests

Open the quest log with **J** (or the Quest Board next to the spawn). A 10-step **story** chain
walks you through every dungeon (XP, coins and skill points), and **3 daily quests** refresh every
day with rewards that scale with your level. Quests are defined in `Config.StoryQuests` and
`Config.DailyQuests`; any tracked stat can drive a quest.

### Prestige

Max level is **50**. At 50, open your Player Card (**H**) > Prestige to reset to level 1 and keep
your gear, coins and skills. Each prestige gives +10% XP, +10% coins, 5 skill points and a new
emblem (10 ranks: Bronze, Silver, Gold, Emerald, Sapphire, Ruby, Amethyst, Obsidian, Celestial,
Godslayer), shown on your card, your HUD and above your head.

### Player cards

Press **H** to customize your card: background, title, frame and 3 showcased stats. Most options
unlock by playing (clearing dungeons, kill counts, owning Godly or Mythic gear, prestige ranks).
You can also view other players' cards. Your title, level and emblem float over your head.
Cosmetics live in `src/shared/Cosmetics.luau`.

### Skills

Earn 1 skill point per level (plus story quests and prestige) and spend them at the **Skill
Sanctum** in the training grounds: Vitality, Strength, Toughness, Agility, Endurance, Precision,
Focus, Fortune and Wisdom. Skills are kept through prestige. See `Config.Skills`.

### Leaderboards & stats

Lifetime stats are saved per player: enemies slain, dungeons cleared, bosses defeated, gold
earned, crates opened, potions, deaths and minutes played. The **Hall of Heroes**, right in front of
the spawn, shows the global top 10 (all servers) for Highest Level (prestige first), Enemies
Slain, Dungeons Cleared and Gold Earned. Press **T** for your own stats and the boards. (Global boards need a published place with
API access; otherwise they rank the players in the current server.)

### Dungeon themes

Each dungeon has its own look, lighting mood and music: the **Crypt** (coffins, skull shelves,
cobwebs, green mist), **Witchwood Hollow** (trees, glowing mushrooms, vines, fireflies, a witch's
cauldron), the **Sunken Temple** (gold-capped columns, jackal statues, sand, treasure), the
**Frozen Keep** (glowing ice crystals, icicles, snowdrifts, falling snow), the **Infernal Forge**
(lava channels, forge pillars, anvils, embers, lavafalls) and the **Abyssal Rift** (void crystals,
floating rocks, rune circles, rifts).

### Admin menu

Admins see an **Admin Menu** button (or press **P**): **Give All Items**, max potions, gold, level,
heal, god mode, clear the current room, teleport to town / training, and give any item by id.
Chat commands work too: `/giveall`, `/level 20`, `/gold 5000`, `/give Dragonfang`.

Admins are: anyone testing in Studio, the game's owner (or rank 254+ in the owning group), and
any user ids added to `Config.AdminUserIds`. The server checks every admin action.

**Creator Rank (owner only):** the game's owner (and user ids in `Config.OwnerUserIds`) also gets
a **CREATOR RANK** button: level **999**, prestige **999**, with its own Creator emblem, "The
Creator" title, Creator's Realm card background and Creator frame. Press it again to go back to
level 50 / prestige 10. Other admins don't see it.

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
    Enemies.luau            every enemy, mini-boss and boss (with boss mechanics + phases)
    Dungeons.luau           dungeons: rooms, boss, rewards, unlock levels + loot per difficulty
    Cosmetics.luau          card backgrounds, titles, frames, prestige emblems, unlock rules
    CardUI.luau             draws emblems and player cards (client + server nameplates)
    WeaponMoves.luau        combo styles + keyframed weapon animations
    Remotes.luau            RemoteEvents/RemoteFunctions
  server/                 -> ServerScriptService.Server
    Main.server.luau        starts the services
    Build.luau              helpers for building scenery from parts
    DungeonDecor.luau       themed decorations for each dungeon style
    ArmorVisuals.luau       builds every armor piece's look and effects on the character
    Sfx.luau                plays sound effects in the world
    Effects.luau            VFX: projectiles, rings, beams, lightning, meteors...
    WeaponModels.luau       builds every weapon's model, glow, aura and swing trail
    WeaponSkills.luau       weapon abilities (R)
    Services/
      DataService.luau      load/save player data
      PlayerService.luau    level, XP, gold, class, items, buffs, stats
      CombatService.luau    combos, weapon + class abilities, loadout (weapon/armor on you)
      EnemyService.luau     builds enemies, AI, ranged shots, boss mechanics
      DungeonService.luau   lobby portals, difficulty picking, parties, dungeon runs, loot
      ShopService.luau      potion shop stall, buying and drinking potions
      HubService.luau       builds the medieval town and sets the lighting
      TrainingService.luau  training grounds: dummies, archery range, sparring ring
      TownsfolkService.luau villagers who walk around and talk, guards, shopkeepers
      MovementService.luau  stamina, sprint and dodge
      AdminService.luau     admin menu actions and chat commands
      CrateService.luau     Crate Shrine, crate odds and opening
      LeaderboardService.luau  lifetime stats -> global leaderboards (Hall of Heroes)
      QuestService.luau     story + daily quests, Quest Board
      ProgressionService.luau  prestige, skills, Skill Sanctum
      CardService.luau      player card customization, nameplates
      ClassService.luau     class rolling (coins / Robux developer product)
  client/                 -> StarterPlayer.StarterPlayerScripts.Client
    Main.client.luau        input (attack, 1, Q/E, R, 2-6, G, T, J, H, P) and wiring
    Controllers/            Movement (sprint/dodge), Audio (music + dungeon lighting),
                            Animator (plays weapon animations)
    UI/                     Hud, Inventory, Shop, PortalPanel, AdminPanel,
                            CrateWindow, StatsWindow, QuestWindow, SkillsWindow, CardWindow,
                            ClassRoller
```

### Adding content

- **New weapon or armor:** add a line to `WEAPON_LIST` / `ARMOR_LIST` in `Items.luau`. It drops
  automatically from any difficulty whose loot includes its tier. A weapon's `Design` picks its
  look, `Combo` its combo style and `Skill` its R ability.
- **New potion:** add it to `Config.Potions` and `Config.PotionOrder`.
- **New class:** add it to `Config.Classes` / `Config.ClassOrder` with a new weapon type and abilities
  (abilities are coded in `CombatService`).
- **New enemy:** add it to `Enemies.luau` (add a `Boss` table to make it a boss).
- **New dungeon:** add it to `Dungeons.Defs` and `Dungeons.Order` with its 4 difficulties. A new portal appears in the lobby automatically.

All maps and enemies are built from code, so no models or assets need importing.
The server checks every action, so players can't cheat by editing their own client.
