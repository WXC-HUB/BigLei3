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
