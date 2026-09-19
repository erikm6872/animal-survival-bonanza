# Combat System

Three small, reusable components under `scripts/combat/`, composed onto
whatever needs them rather than baked into the player controllers.

## `Damageable` (`damageable.gd`)

```gdscript
extends Node
class_name Damageable

signal damaged(amount: float, source: Node)
signal died(source: Node)

@export var max_health: float = 100.0
var current_health: float
var is_dead: bool
var is_invulnerable: bool  # e.g. during a dodge's i-frames

func take_damage(amount: float, source: Node = null) -> void
```

Attach as a child node named `"Damageable"` to anything that should be
hittable — both player controllers have one, and so does
`training_dummy.gd`. `take_damage()` is a no-op while `is_dead` or
`is_invulnerable`; otherwise it clamps health, emits `damaged`, and emits
`died` once on the transition to zero health. Callers connect to both
signals to drive their own hit-react/death animations and HUD updates —
`Damageable` itself has no opinion about what "dying" looks like.

## `Hitbox` (`hitbox.gd`)

```gdscript
extends Area3D
class_name Hitbox

@export var damage: float = 15.0
@export var owner_body: Node  # ignored as a target, so an attacker can't hit itself

func activate() -> void   # opens the damage window
func deactivate() -> void # closes it
```

An `Area3D` that only registers hits while `activate()`d, closed again by
`deactivate()`. Looks for a child node literally named `"Damageable"` on
anything it overlaps (`get_node_or_null("Damageable")`) — that's the whole
contract for "is this hittable," not a group or a custom interface.
`activate()` also checks everything *already* overlapping (not just new
`body_entered`/`area_entered` signals), since a hitbox that opens while
already inside its target shouldn't miss the hit.

Both player controllers open their hitbox for a window computed from the
species' Attack clip:

```gdscript
var attack_length := anim_player.get_animation(species.anim_attack).length
attack_hit_start = attack_length * species.attack_hit_start_fraction
attack_hit_end = attack_length * species.attack_hit_end_fraction
```

then activate/deactivate it as `attack_time` crosses those two thresholds
each frame. The fractions are tuned per species by eye, to line up with
that specific clip's actual bite/lunge frame — there's no generic way to
derive them from the animation data.

## `Stamina` (`stamina.gd`)

```gdscript
extends Node
class_name Stamina

signal changed(current: float, max_stamina: float)

func try_spend(amount: float) -> bool  # one-shot cost (attack, dodge); refuses if not enough
func drain(amount: float) -> void      # continuous cost (sprinting); partial is fine
```

Regenerates after `regen_delay` seconds of no spending, and enters an
"exhausted" state on hitting zero — exhausted actors can't `try_spend()` or
`drain()` again until stamina regens back above
`exhausted_recovery_fraction` (25% by default). That recovery floor exists
specifically to avoid flicker at empty: without it, stamina regenerating
past zero by a hair would immediately allow — then re-drain — another
action, every frame.

## How it's wired together

Nothing in `scripts/combat/` references `AnimalSpecies`, `GameState`, or
either movement controller — the coupling runs the other direction. Each
controller's `_ready()` copies species stats onto its components once:

```gdscript
damageable.max_health = species.max_health
damageable.current_health = species.max_health
hitbox.damage = species.attack_damage
hitbox.owner_body = self
```

and connects to their signals to drive its own animation/HUD/respawn logic
(`_on_damaged`, `_on_died` in both controllers). This is why the same three
components work unmodified for a training dummy, a ground animal, and a
flying animal: they don't know or care what's attached to them.
