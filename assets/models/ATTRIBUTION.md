# Asset sources

All assets below are CC0 (public domain) — no attribution legally required,
credited here for provenance.

- **Wolf.gltf, Stag.gltf, Fox.gltf** — Quaternius, "Ultimate Animated Animal
  Pack" (https://quaternius.com/packs/ultimateanimatedanimals.html). Wolf
  animations: Attack, Death, Eating, Gallop, Gallop_Jump, Idle, Idle_2,
  Idle_2_HeadLow, Idle_HitReact1, Idle_HitReact2, Jump_ToIdle, Walk. Stag
  animations: Attack_Headbutt, Attack_Kick, Death, Eating, Gallop,
  Gallop_Jump, Idle, Idle_2, Idle_Headlow, Idle_HitReact1, Idle_HitReact2,
  Jump_toIdle, Walk. Fox has the same animation set/names as Wolf — same
  pack, but not always identical clip names across animals, which is why
  species stats/animation names live in `resources/species/*.tres` (and
  `resources/enemies/*.tres` for hostile wildlife) rather than being
  hardcoded. Fox is the first hostile enemy, used by
  `scripts/enemies/enemy_controller.gd`.
- **nature-kit/** — Kenney, "Nature Kit" (https://kenney.nl/assets/nature-kit).
  See `nature-kit/LICENSE.txt`.
- **fish/** — Quaternius, "Animated Fish Pack"
  (https://quaternius.com/packs/animatedfish.html). Fish1, Fish2, Fish3 used
  for ambient fish in the river/ponds; Dolphin/Manta ray/Shark/Whale from the
  same pack not used yet. Each has a single "Swim" animation.

The playable Sparrow (flight species) uses no external model — no CC0 or
commercial-use-safe rigged/animated bird asset could be found (Quaternius's
animal packs have no birds at all; their "Monsters" pack's only flying
options are fantasy creatures, e.g. its "Pigeon" is a purple tentacled
blob-monster, not a bird; the best real bird found was CC-BY on Sketchfab but
gated behind an account login). It's built procedurally in
`scripts/player/simple_bird_model.gd` from primitive meshes with code-driven
wing-flap animation, the same approach used for the terrain/water/fish.
