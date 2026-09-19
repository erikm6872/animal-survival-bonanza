# Movement Controllers

Two `CharacterBody3D` scripts, both driven by an `AnimalSpecies` resource
(see [Species System](Species-System.md)):

- **`scripts/player/player_controller.gd`** — ground movement (Wolf, Stag).
- **`scripts/player/flight_controller.gd`** — flight movement (Sparrow),
  including landing and ground-hopping.

They're independent scripts, not a shared base class with two subclasses.
Full 3D movement with no gravity/floor is different enough from
gravity-plus-floor ground movement that a shared `_physics_process` would
mean branching almost every line of it. `flight_controller.gd`'s top
comment documents this as a deliberate choice, accepting the component
wiring/damage/death/respawn/fur-color duplication (~100 lines) rather than
refactoring the already-working ground controller.

## Shared conventions

Both controllers:

- Read all stats/animation names/combat tuning from `species` (never
  hardcoded).
- Wire the same component set via `@onready`: `camera_pivot`/`spring_arm`/
  `camera` (third-person rig), `model` (the instanced species mesh),
  `hitbox`/`hitbox_shape` (melee), `damageable`, `stamina`, `hud`. See
  [Combat System](Combat-System.md) for the component internals.
- `_spawn_model()` instances `species.model_scene` under `$Model` and
  applies a flip transform:
  ```gdscript
  instance.transform = Transform3D(
      Basis.IDENTITY.scaled(Vector3(-species.model_scale, species.model_scale, -species.model_scale)),
      Vector3.ZERO,
  )
  ```
  Every asset pack used here (Quaternius) models face **+Z**, but this
  project's movement convention is **-Z-forward** (matching Godot's default
  camera-forward). Negating X and Z scale mirrors the model to face the
  right way without needing per-species special-casing. Anywhere movement
  direction becomes a yaw angle, expect `atan2(-dir.x, -dir.z)` rather than
  the more usual `atan2(dir.x, dir.z)` — that's the same convention showing
  up in the math.
- `_find_animation_player()` walks the instanced model's children looking
  for an `AnimationPlayer`, rather than assuming a fixed path — the two
  Quaternius rigs (Wolf/Stag) and the procedural bird model
  (`simple_bird_model.gd`) don't put it at the same relative path.
- Implement matching `get_fur_color()`/`set_fur_color()`, so the pause
  menu's color picker doesn't need to know which controller is active (see
  [UI and Menus](UI-And-Menus.md)). The Sparrow leaves `fur_mesh_path`
  empty and these become no-ops — it has no single tintable surface.
- Attack: `hitbox.activate()` while `attack_time` is between
  `attack_hit_start` and `attack_hit_end` (computed from
  `species.attack_hit_*_fraction` × the Attack clip's actual length),
  `deactivate()` outside that window or when the clip finishes.
- Dodge: a fixed-speed burst in the current movement direction (or
  backward, if no input is held) for a fixed duration, with
  `damageable.is_invulnerable = true` for the same window — the i-frames.

## Ground controller specifics

- Real gravity (`ProjectSettings` default) applied whenever
  `not is_on_floor()`.
- `jump` performs an actual jump (`velocity.y = jump_velocity`) when
  `is_on_floor()`.
- Facing uses **yaw only**: `model.rotation.y` lerped toward
  `atan2(-move_dir.x, -move_dir.z)`.
- The dodge is a full end-over-end roll: `model.rotation.x` sweeps a full
  `TAU` over the dodge duration, and `model.position.y` arcs up via
  `sin(roll_progress * PI) * DODGE_HOP_HEIGHT` — without the arc, the roll
  (which pivots around the model's origin, at foot level) sweeps the body
  below the floor while upside-down.

## Flight controller specifics

- **No gravity, no floor**, while airborne — `_clamp_above_ground()` is the
  only thing stopping the bird from flying underground: it clamps
  `global_position.y` to `TerrainHeight.get_height(x, z) + min_ground_clearance`.
- Movement is **full 3D**, not flattened: `forward`/`right` come straight
  from the camera basis with no `.y = 0` step, so looking up/down and
  pressing forward climbs/dives.
- Facing uses full 3D orientation: `_face_direction()` builds a target
  `Basis.looking_at(direction, Vector3.UP)` and `slerp()`s toward it, so the
  model pitches to match its actual flight vector, not just its yaw.
- Dodge has no elaborate roll — a bird already airborne doesn't need one —
  just a fast burst using `_face_direction()` for orientation.

### Landing and ground-hopping

`is_landed: bool` is the flight controller's mode switch, toggled by the
`jump` action (reused as a contextual land/take-off key rather than adding
a new input action):

```gdscript
if Input.is_action_just_pressed("jump"):
    if is_landed:
        is_landed = false
        velocity.y = TAKEOFF_VELOCITY
    elif global_position.y - TerrainHeight.get_height(global_position.x, global_position.z) <= LAND_MAX_HEIGHT:
        is_landed = true
        _level_model_orientation()
```

Landing is only allowed within `LAND_MAX_HEIGHT` of the ground — no landing
out of a high-altitude dive. While `is_landed`:

- **Real gravity and floor collision take over**, the same
  `is_on_floor()`/`move_and_slide()` pattern the ground controller uses,
  instead of the no-gravity hover model.
- Movement input is **flattened to the horizontal plane** (`forward.y = 0`,
  `right.y = 0`) — looking up/down shouldn't tilt a hopping bird's ground
  direction the way it tilts flight.
- Speed is scaled down (`GROUND_SPEED_SCALE`) — hopping is slower than
  cruising flight.
- Animation switches to `species.anim_hop`/`anim_ground_idle` (falling back
  to `anim_walk`/`anim_idle` if the species left those empty).
- `_level_model_orientation()` snaps the model's pitch/roll back to level
  the instant it lands, keeping only its current yaw. Without this, landing
  out of a dive leaves the model pointed nose-down into the ground — the
  facing-basis slerp would eventually correct it, but only while there's
  movement input to drive it, so a bird that lands and immediately stops
  input would stay stuck at the dive angle.

Taking back off gives an upward `TAKEOFF_VELOCITY` impulse and resumes the
no-gravity flight model; with no sustained forward input the vertical
velocity bleeds off via the normal `move_toward` deceleration; like the
rest of flight, this is an arcade hover model, not simulated lift.
