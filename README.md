# Train Hole

**First-person zombie train survivor** — fight through procedurally generated train cars, board up windows, earn coins, and upgrade gear in the gangway shop between waves.

> **Note:** An earlier prototype lives in [zombietrain](https://github.com/miles5g/zombietrain). This repo is the current Godot 4.6 version with expanded systems.

## Highlights

- **Infinite train** — new CSG cars spawn ahead; oldest cars despawn (3-car window)
- **Procedural interiors** — windows, flickering lights, gangways, 0–5 barriers per window
- **Window combat** — zombies climb through openings; difficulty scales with car depth
- **Economy loop** — coins, gangway shop (**E** in safe zone), damage/health/weapon upgrades
- **Dual loadout** — starter weapon picker, **Q** to swap, melee block (**RMB**), barrier repair (hold **R**, 10 coins)
- **Persistence** — cosmetic/meta save at `user://train_hole_save.json`

## Stack

- Godot **4.6**, GDScript, **Jolt Physics**
- 3D CSG generation (`caboose_generator.gd`)
- Autoloads: `GameState`, `WeaponRegistry`

## Run locally

1. Install [Godot 4.6](https://godotengine.org/download) with Jolt support.
2. Open this folder in Godot.
3. Press **F5** (`world.tscn`). On first launch, pick a starter weapon.

## Controls

| Input | Action |
|-------|--------|
| **WASD** | Move |
| **Mouse** | Look |
| **Space** | Jump |
| **Ctrl** | Sprint |
| **Shift** | Crouch |
| **LMB** | Melee attack |
| **RMB** | Block (melee) |
| **E** | Interact / gangway shop (safe zone) |
| **Q** | Swap weapons |
| **R** (hold) | Add window barrier (costs coins) |

## Project layout

```
train-hole/
├── world.tscn
├── scripts/           # Player, zombies, game state, weapons
├── scenes/
└── project.godot
```

## Status

Playable prototype — core loop, shop, and procedural cars are in; polish and content ongoing.

## License

MIT (see repository license if present).
