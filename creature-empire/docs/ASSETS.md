# Asset manifest

Everything in the game is built from code, so it runs with no imported assets. This file lists what should be imported to reach release quality, and where each asset goes.

**Rule:** never paste an asset id you haven't uploaded or verified yourself. Empty ids are safe: sounds stay silent, images fall back to glyphs, creatures use code-built models. A test (`Config.spec.luau`) fails if an id is anything other than empty or a built-in `rbxasset://` path.

## Sounds → `src/shared/Config/AssetConfig.luau` (`AssetConfig.Sounds[key].Id`)

Formats: OGG or MP3, mono for 3D effects, normalised to about −14 LUFS. Every sound plays with the random pitch range in its entry, so keep recordings neutral.

| Key | Category | Length | Description |
| --- | --- | --- | --- |
| `UiClick` | UI | < 0.1 s | Soft wooden tick. Currently uses the built-in `electronicpingshort.wav` as a fallback. |
| `UiOpen` / `UiClose` | UI | 0.2 s | Paper or glass "whoosh" up and down. |
| `UiError` | UI | 0.2 s | Gentle low "bonk", not harsh. |
| `Notify` | UI | 0.3 s | Light chime. |
| `QuestComplete` | Reward | 1 s | Rising three-note fanfare. |
| `Collect` | Building | 0.4 s | Bundle of petals: soft rustle and sparkle. |
| `Sell` | Building | 0.5 s | Coins into a pouch. |
| `Place` | Building | 0.6 s | Wooden thunk and dust. |
| `Upgrade` | Building | 1.2 s | Hammering then a magical shimmer. |
| `Harvest` | Building | 0.3 s | Tiny pluck (played often, keep it quiet). |
| `CreatureObtain` | Reward | 1.5 s | Creature joins (quest rewards): sparkle swell. |
| `Hatch` | Reward | 1.5 s | Egg crack, then a happy chirp. |
| `Evolve` | Reward | 2 s | Rising shimmer and a deep "whoom". |
| `AbilityCast` | Creature | 0.6 s | Generic cast whoosh (per-family variants later). |
| `<species>_idle` (all 32 species) | Creature | 0.5–1 s | Species vocalisation: Sproutling coo, Cindercub chuff, Pebblit gravel giggle. |
| `<species>_move` | Creature | 0.15 s | Footstep: leaf patter, ash puff, stone tap. |
| `<species>_work` | Creature | 0.3 s | Working: snip, crackle, dig. |
| `MusicEmpire` | Music | 2–3 min loop | Calm, optimistic plucked strings and woodwinds. Must loop seamlessly. |
| `AmbienceVerdant` | Ambience | 1–2 min loop | Meadow: wind, birds. Night variant later. |
| `AmbienceEmberfall` (to add, Phase 3) | Ambience | 1–2 min loop | Low lava rumble, distant hiss, crackling embers. Not wired yet: add the key and play it from `RegionController.applyMood`. |
| `GuardianSlam` / `GuardianRoar` (to add, Phase 3) | Creature | 1 s | Huge stone impact; deep molten roar on phase change. The slam currently reuses `AbilityCast`. |

## Images → `AssetConfig.Images`

| Key | Size | Description |
| --- | --- | --- |
| `Gold`, `Essence`, `EmpireShards`, `Moonpetal` | 128×128 PNG, transparent | Currency and material icons. Until set, the HUD uses the glyphs ● ✧ ⬢ ✿. |
| `GameIcon` | 512×512 | Experience icon: a Sproutling, Cindercub and Pebblit around the glowing core crystal. |
| `SpinWheelFace` | 1024×1024 PNG, transparent corners | The face of the wheel in the Spin Wheel window, seen straight on and centred, with no frame or pointer. It turns as one picture. Slices go clockwise in `SpinConfig.Prizes` order with 1,000 Gold at the top (`SpinConfig.WheelOffset` = -112.5): 1,000 Gold, 25 Essence, 2,500 Gold, 2× Luck, 5,000 Gold, Black Dragon, 500 Gold, 2× Coins. Until set, the wheel is drawn in code. |
| `SpinWheelFrame` | 1030×1030 PNG, transparent | Optional. A ring or frame (vines, wood, the centre flower) drawn over the wheel. It doesn't turn. Leave the middle see-through. It is drawn 1.334× the face's size (`FRAME_SCALE` in `SpinWindow`), centred on it. Both pictures for the current wheel are in `creature-empire/art/`. |
| Thumbnails | 1920×1080 | Upload in the Creator Dashboard (not used by code). |

## Creature models (optional) → `ReplicatedStorage/Assets/Creatures/<SpeciesId>`

`client/Visuals/CreatureModels.luau` uses a hand-made model automatically if it exists:

- A `Model` named after the species id (for example `Sproutling`), with a `PrimaryPart` named **Root** at the body centre.
- All other parts welded to Root, `Anchored = false`, `CanCollide = false`, `Massless = true`.
- Juvenile scale, about the height of the code version (2–4 studs). Evolution stages scale it with `ScaleTo`.
- Optional: an `Attachment` named `FeetAttachment` with a `ParticleEmitter` named `Footstep`, and an `AmbientAttachment` with an emitter named `Ambient`. The animator uses them if present.

## Creature animations (optional) → `AssetConfig.Animations[speciesId] = { Idle, Walk, Work }`

Phase 1 animates creatures procedurally (hop, peck, spin, nap). Rigged models can supply looping `Idle`, `Walk` and `Work` animations of 0.5–1.5 s each. The animator needs a small change to play them; see the roadmap, Phase 6.

## Building models (optional)

Each builder in `server/World/BuildingModels.luau` can be swapped for a cloned model. Keep these conventions:

- The `PrimaryPart` is named `Base` and covers the footprint (4 studs per cell).
- `WorkSpot1..3` attachments mark where workers stand.
- Parts named `Petal` are crops the client brightens as storage fills.
- A part named `FillGauge` is the silo level indicator.
- Models tagged `CE_Spin` (with `SpinSpeed` and `SpinAxis` attributes) spin; parts tagged `CE_Bob` (with `BobHeight`) float.

Provide one model per level, or one model with level-specific parts toggled by the builder.

## Particle textures

These use textures that ship with the Roblox client (`rbxasset://textures/particles/...`). They can be replaced with custom leaf, ember, glint and bubble sprites (64×64 PNG, white on transparent, so the colour comes from the emitter).

## Creature models (replacing the code-built look)

Any species can use a hand-made 3D model instead of the code-built one. The game picks it up automatically everywhere the creature appears: plots, wild, companions, portraits, reveals and trades.

**From an FBX:**
1. Open `creature-empire.rbxl` in Roblox Studio.
2. Go to the **Home** tab and choose **Import 3D**, then pick your `.fbx`. Keep "Import as Model" on and include the textures. This uploads the meshes to your Roblox account.
3. Rename the imported model to the species id, for example **`Sproutling`**.
4. Make sure its face points the way the creature should walk. It should face −Z: in Studio's front view, the face looks away from the camera's default direction. If it faces backwards, add a number attribute **`Facing` = `180`** to the model. Use `90` or `-90` for sideways.
5. Test it straight away: put the model in **ReplicatedStorage › Assets › Creatures** and press Play.
6. Keep it in the project: right-click the model, choose **Save to File…**, save it as `Sproutling.rbxm` and put it in `creature-empire/assets/Creatures/`. Rojo builds then include it every time.

**What the game does with it (`client/Visuals/CreatureModels.luau`, `prepareCustom`):**
- Resizes it to the species' height (`Appearance.Size`, ×1.3 at Mature and ×1.6 at Ascended). Add a boolean attribute **`KeepSize` = true** to keep your own size; evolution still scales it.
- Welds every part to a new invisible anchored `Root` at the model's centre. Existing welds, Motor6Ds and anchoring are replaced.
- Makes it non-colliding and massless.
- Applies mutations as a recolour plus sparkle. SurfaceAppearance textures keep their look, but parts with plain colours get tinted.
- Uses optional extra models per stage: `Sproutling_2` (Mature) and `Sproutling_3` (Ascended). Without them, the stage-1 model is scaled up.
- An optional number attribute **`HeightOffset`** lifts the model if it sinks into the ground.

**Ownership:** uploaded meshes belong to the account that imported them. Publish the game from the same account (or from a group that owns the meshes), or they won't load in the live game.

**Rigged models and animations:** a model with a `Humanoid` or `AnimationController` keeps its joints. Only its root part is welded to the game's invisible Root. Give it animations with string attributes on the model: `IdleAnimation`, `WalkAnimation` and `WorkAnimation`, each set to `rbxassetid://…`. You can also put them in `AssetConfig.Animations[speciesId] = { Idle = …, Walk = …, Work = … }`. Upload the animations from the same account or group that owns the game.

## Monetization ids → `src/shared/Config/MonetizationConfig.luau`

1. On the Creator Dashboard, open your experience and go to **Monetization**. Create a **Pass** for *Supporter* and a **Developer Product** for *Production Boost · 30 min*.
2. Paste their ids into `Passes.Supporter.Id` and `Products.Boost30.Id`.
3. Rebuild. The shop (K) now shows prices and buy buttons.

While an id is `0`, the shop shows "Coming soon" and the server refuses that item. Don't add items that sell random rewards: the tests check that only boosts are sold.

## Building and world models (replacing the code-built look)

Every building and some world pieces can be swapped for your own models, made in Studio or imported (FBX → **Import 3D**). The game does the fitting for you.

**Buildings** go in **ReplicatedStorage › Assets › Buildings**, named after the building type:

| Name | Building | Space it's fitted into |
| --- | --- | --- |
| `EmpireCore` | Empire Core | 16 × 16 studs |
| `MoonpetalFarm` | Moonpetal Farm | 16 × 16 studs |
| `CrystalMine` | Crystal Mine | 16 × 16 studs |
| `CrystalSmelter` | Crystal Smelter | 12 × 12 studs |
| `EssenceCondenser` | Essence Condenser | 12 × 12 studs |
| `ExpeditionPortal` | Expedition Portal | 16 × 16 studs |
| `Hatchery` | The Hatchery nest in the plaza | 12 × 12 studs |
| `EvolutionChamber` | Evolution Chamber | 16 × 16 studs |
| `ResourceSilo` | Resource Silo | 12 × 12 studs |
| `TradingPost` | The Trading Post (shop) in the plaza | 12 × 12 studs |
| `Habitat` | Creature Habitat | 20 × 16 studs |
| `ResearchStation` | Research Station | 16 × 16 studs |
| `CourierPost` | Courier Post | 12 × 12 studs |

- **Placement:** the model is resized to fit that space (a little smaller, for a margin) and stood on the plot floor, centred. Add a boolean attribute `KeepSize` = true to use your own size instead.
- **Per-level looks:** add models named `TradingPost_2`, `TradingPost_3`, and so on. The highest one up to the building's level is used, and the plain name covers everything else.
- **Front:** the front of a building faces the plot's entrance path. If yours faces the wrong way, add a number attribute `Facing` set to `90`, `180` or `-90`.
- **Where creatures stand to work:** put Attachments named `WorkSpot1`, `WorkSpot2` and `WorkSpot3` in your model where they should stand. Without them, the creatures stand in a row in front of the building.
- **Prompts and labels:** the game adds the "Manage" and "Collect" prompts and the name/level label itself. Don't include your own.

**World pieces** go in **ReplicatedStorage › Assets › World**:

| Name | Replaces | Notes |
| --- | --- | --- |
| `FenceSegment` | The plot fence (curb, posts and rails) | One section of fence built along its **X axis** (left to right). Copies are laid end to end around every plot, slightly stretched to fill each side exactly. About 6–8 studs long works well. |
| `PathSegment` | The paths from the plaza to the plots, and the path inside each plot | One piece of path built along its **X axis** (length), with its width along Z. It's sized to the path's width (8 studs), then copies are laid end to end and stretched slightly to fill each path. Also found as `Path`, `GravelPath` or `Gravel`. |
| `Tree` | The trees around the world | Sized to 13 studs tall (unless `KeepSize`), then given a random turn and the size variation of the originals (about 1.2–1.9×). |
| `Rock` | The rocks around the plaza | Same as trees. |
| `Lamp` | Lamp posts on the plaza and paths | Scaled to 11 studs tall (unless `KeepSize`); a warm light is added near the top. |
| `SpinWheel` | The Spin Wheel in the plaza | Stands on a 14 × 6 stone plinth, scaled to 16 studs tall. Its front faces the Founders' Crystal. |

**To try one:** put the model in the folder and press Play. Studio models keep their exact look; only the size and position are adjusted. **To keep it:** right-click the model, choose **Save to File…**, and put the `.rbxm` in `creature-empire/assets/Buildings/` or `assets/World/` so every build includes it.

## Big models: load them by asset id

A `.rbxm` file can be too big to share or keep in the project (imported meshes with textures easily pass 30 MB). Load the model from Roblox instead:

1. In Studio, open **Toolbox → My Models**. Right-click your model and choose **Copy Asset ID**. The id is also shown in the model's **Asset Configuration** window.
2. Add it to `AssetConfig.ModelAssets` in `src/shared/Config/AssetConfig.luau` under the right category, using the same name a model in the folder would have:
   ```lua
   AssetConfig.ModelAssets = {
       Creatures = { Sproutling = 120629196068989 },
       Buildings = { TradingPost = 1234567890 },
       World = { FenceSegment = 1234567890 },
   }
   ```
3. When the server starts (`server/World/AssetLoader.luau`), it loads each one with `InsertService:LoadAsset` into `ReplicatedStorage/Assets/<Category>/<Name>`. The game then treats it exactly like a model you placed there. Any scripts inside are removed.

Rules:
- The model asset must belong to the **same account or group that owns the game**, or Roblox refuses to load it. The Output shows a "Could not load model" warning when that happens.
- A model you put in the folder by hand takes priority over the asset id.
- Attributes like `Facing` and `HeightOffset` are part of the uploaded model. After changing them, re-upload: right-click the model → **Save to Roblox**, then choose your existing model to overwrite it so the id stays the same.
- Keep imported creatures light: roughly a few thousand triangles and 1024 px textures. Dozens of creatures can be on screen at once.
