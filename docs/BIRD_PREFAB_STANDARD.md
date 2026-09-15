# Bird Perch Prefab Standard

Every interactive bird is packaged as one self-contained Godot scene using the
`BirdPerch` script. The branch and bird artwork must remain separate.

## Required node contract

- Root `Control` using `BirdPerch` (`448 × 336` reference canvas)
- `Tree` — fixed perch/branch `TextureRect`
- `Sprite` — bird-only `TextureRect`; this is the animated layer
- `HitArea` — transparent `Button` covering the bird interaction area
- `ActionSFX` — one-shot `AudioStreamPlayer`

## Required assets

- Four or more transparent idle frames with identical `220 × 220` canvases
- Two transparent `_find` anticipation frames
- One `_find_yes` result frame
- One `_find_no` result frame
- For non-find birds, one or more generic action frames instead of Yes/No frames
- One branch/perch image on a `448 × 336` transparent canvas
- Optional one-shot bird voice assigned to `ActionSFX`

## Runtime contract

- `play_find(found_mine: bool)` owns the complete find animation.
- `true` ends on `_find_yes`; `false` ends on `_find_no`.
- `play_action()` plays a configured generic action sequence for item-linked birds.
- Concurrent requests are serialized, never blended.
- Only `Sprite` animates. `Tree` must never move with the idle rhythm.

## Cutting frames from a green-screen sheet

`python tools/cut_bird_sheet.py <sheet.png> <prefix>` turns a 2 × 4 sheet
(row 1 idle, row 2 action, a circled number under each frame) into the files
above: `my_asset/birds/<prefix>_idle_N.png`, `<prefix>_action_N.png` and the
256 × 256 shop/board icon `assets/sprites/generated/bird_items/item_bird_<prefix>.png`.
Birds are picked as connected blobs, so tails crossing grid lines stay with
their own frame; all eight frames share one scale so the body never pops, and
the idle frames share a baseline so the feet stay on the branch. Keep the
source sheet in `my_asset/birds/source/` (that folder carries a `.gdignore`).

## Current perches

| Scene | Bird | Item | Action frames |
|---|---|---|---|
| `blue_bird_perch` | 点点小蓝鸟 | find (yes/no) | 2 find + yes + no |
| `red_bird_perch` | 红尾水鸲 | 罗盘 | 2 fly |
| `black_bird_perch` | 夜鹭 | 灯笼 | 2 fly |
| `attacker_bird_perch` | 啄木鸟 | 轰击 | fly + peck |
| `eg_bird_perch` | 红隼 | 无敌 | none (giant flyover is a separate effect sprite) |
| `tit_bird_perch` | 长尾山雀 | 巨大 | slip, flap, dive, crash — bird falls from the branch onto the target cell, then tumbles off the bottom of the screen and fades back in |
| `magpie_bird_perch` | 灰喜鹊 | 连携雷 | stride, squint, glare, sparkle — flight cycle. Mark any mine in the level's chain group and it flies from that cell to each remaining chain mine in turn, marking them, then fades out and reappears |
| `crow_bird_perch` | 小嘴乌鸦 | 透视 | lean, lift, startle, flee. It flies to the cell the x-ray picked, lifts the card's corner to show the content for three seconds without flipping it, then is startled off the screen and comes back on its own. Its sheet is drawn **facing left**, so the prefab sets `art_faces_right = false` |
| `dove_bird_perch` | 斑鸠 | 治愈 | hold-twig, walk-with-twig, 2 fly — three idle frames only (frame 4 is unused). It flies to the healing card, picks the twig up there, carries it to the health bar and the heart only comes back when it arrives, then fades out on the spot. Drawn **facing left**, so `art_faces_right = false` |

## Where the perches go

`scenes/main.tscn` places all nine perches, and the rule is solved rather than eyeballed —
`relayout_perches.py` in the scratchpad does it and is worth rewriting rather than nudging
offsets by hand.

A bird's size is how much of it is actually **painted** — the count of opaque pixels per idle
frame, averaged over the loop, square-rooted — not the longest side of its bounding box.
Normalising by the bounding box is what makes the sizes look wrong: a bird trailing a long thin
tail (the magpie fills 38% of its box) gets blown up until its body looks small, while a solid
one (the crow, 69%) gets squashed. Under the box rule the visual mass ranged 167 to 229 across
the nine; under the mass rule they match at 195, which is the number to change if the birds
should all be bigger or smaller. Measure through the Sprite's own scale (some prefabs carry one
— blue is at 0.775) and through KEEP_ASPECT_CENTERED letterboxing (the square frame is fitted
inside the Sprite rect, not stretched to fill it). Three traps, all of which have cost a round
trip: PIL's `getbbox()` counts RGB in fully transparent pixels, so measure `getchannel("A")`;
the first texture in a perch prefab is the **branch**, so resolve the `idle_frames` ExtResource
ids instead; and `uid="…"` also matches an `id="…"` regex.

The board owns the middle. Measured at every level, it caps at a 10×10 whose cells span
x 477..1441, y 78..1041 — which means **there is no bottom band**: 39px under the board is not
a bird. The only free space at every board size is the two outer strips, so that is where the
birds go, zigzagging between two lanes down each one. The inner lane has to be set by the
*widest* bird, not a typical one: at equal mass a long-tailed bird's box is much wider (332px
for the redstart against 213 for the crow), and a lane placed for the narrow ones puts tails on
the board.

Each column stacks **up from the bottom edge** — every bird's feet align to the bottom of its
slot and the last one's feet land on the screen edge — so both sides of the frame are occupied
all the way down and any slack collects at the top, out of the way. The outer lane is a
*negative* inset, letting the edge birds hang a little off screen so they read as leaning in
rather than lined up.

Nine birds at this size do not fit those strips without touching, so neighbours deliberately
overlap at the branch corner and `z_index` rises down each column: the overlap then reads as a
tree with depth instead of two birds stuck together. Every bird stands on a branch, and the
branch is derived from its art box (1.15× the art width, its top surface at 56.5% of the
texture height, sunk 5% into the feet), so it is actually under the bird rather than near it.

Position the perches with **anchors, not absolute offsets**. The project runs
`stretch/aspect="expand"`, so a window with a different aspect gives a viewport wider or taller
than 1920×1080 and anything at a fixed coordinate stops touching the edge it was meant to hug.
Each perch anchors to the horizontal edge its column belongs to and to whichever vertical edge
it is nearer, with `grow_*` pointing the same way. Verified by resizing the root viewport: at
2400×1080 nothing drifts from its edge at all.

Changing the perch scale changes the on-board size too — retune `board_travel_scale` in the same
pass (285 × 0.34 ≈ 97px, just over one 88px cell).

## Birds that work on the board

A perch sprite is drawn about three cells wide, which is right for the edge of the screen and
far too big out on the grid — it buries the very cell it is acting on. Any bird that flies onto
the board sets `board_travel_scale` on its prefab (0.34 gives roughly one cell at the current 285px perch size); `begin_travel_action`
applies it and every way home (`reset_to_idle`, `reappear_on_perch`, `fade_out_travel_sprite`)
puts it back. The sprite scales about its own centre, so `get_launch_global_position()` and the
`*_to_global_center` helpers measure with the **perch's** scale, never the sprite's own — folding
the shrink into that maths lands the bird half a shrink away from where it was aimed.

Land beside the target cell rather than on it, and leave as soon as the beat is played: the
content a bird reveals has to stay readable after it goes.

When a bird acts on several cells at once, send one instance per cell rather than walking a single bird around them — a queue of hops gets long fast and reads as waiting. Spawn the copies on the effects layer, size them from the perch's `board_travel_scale`, and stagger their launches slightly.

Drive flapping frames from **elapsed time** (`progress * duration / FLAP_TIME`), and keep that tween linear. Easing the flight also eases the frame counter, so the wings stall at both ends of the hop.

## Bird codex entry

Every bird also owns a card in the title-screen codex (`scripts/ui/bird_codex_screen.gd`).
Adding a bird means adding one entry to `BirdCatalog.ENTRIES`
(`scripts/game/bird_catalog.gd`: id, name, nickname, one-line ability, unlock condition,
the prefab's idle frames and its `art_faces_right`) **and** one line in `main.gd`'s
`_bird_unlock_states()` mapping that id to the bird's `*_unlocked` flag. Miss the second
half and the card sits at a permanent silhouette no matter what the save says.
The page lays itself out in two rows and divides the width by the roster size, so a new
bird needs no layout work; check it with `tools/capture_bird_codex.gd`.

## Unlock page & easter egg checklist

Every bird after the blue one ships with an unlock ceremony (`scenes/ui/<bird>_unlock.tscn`,
presented from the victory branch of its tutorial level in `main.gd`), a first-level demo
(`_place_unlocked_<bird>_in_first_reveal` pins one card into the first revealed region), and
one hover easter egg on the ceremony page that reports an `AchievementCatalog` id through
`easter_egg_triggered`. The long-tailed tit's egg: every hover spawns a chick, twelve chicks
merge into a bowl of tangyuan (`my_asset/tangyuan_bowl.png`).

## Adding a bird that takes over an item (checklist)

1. Frames: `python tools/cut_bird_sheet.py my_asset/birds/source/<sheet>.png <prefix>`; extra art (icons, props) via a `tools/build_<prefix>_assets.py`.
2. Perch: copy `scenes/birds/tit_bird_perch.tscn` (branch) or `magpie_bird_perch.tscn` (ground); place it in `scenes/main.tscn` at a screen edge, `z_index = 50`.
3. `scripts/main.gd`: `@onready` perch var; add it to every `[_blue_bird, ...]` list and `_apply_bird_unlock_visibility`; `_<x>_bird_unlocked` flag saved/loaded (default to `tutorial_completed` for old saves) and set wherever the other flags are force-set (skip tutorial, stage run, duel, custom, reset); item stock default and its `bird_only_tutorial` gate; rename the item's display name, tooltip, shop offer, custom-level name and editor/shop/board icons.
4. Tutorial: bump `TUTORIAL_LEVEL_COUNT`, add a board to `grass_1` in `stage_table.gd`, move the previous last unlock to `_start_game(); return`, add the new unlock page in the victory branch, arm a `_<x>_demo_pending` for the first normal level.
5. Unlock page: copy `scenes/ui/tit_unlock.tscn` + script, wire `easter_egg_triggered` in `_ready`'s unlock-page list, add the achievement to `achievement_catalog.gd`, add the bird to `credits_bird_swarm.gd`.
6. Tests: perch test, gameplay test, unlock-page test, tutorial test; extend `test_easter_egg_achievements` and `test_credits_bird_swarm`; fix tests that hard-code the tutorial length. Run `godot --headless --import` first.
