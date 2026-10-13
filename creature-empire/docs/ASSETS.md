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

## Images → `AssetConfig.Images`

| Key | Size | Description |
| --- | --- | --- |
| `Gold`, `Essence`, `EmpireShards`, `Moonpetal` | 128×128 PNG, transparent | Currency and material icons. Until set, the HUD uses the glyphs ● ✧ ⬢ ✿. |
| `GameIcon` | 512×512 | Experience icon: a Sproutling, Cindercub and Pebblit around the glowing core crystal. |
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
