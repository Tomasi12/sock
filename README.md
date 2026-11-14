# The Last Sock

A funny 2D side-view prototype made with **Godot 4** and **GDScript**.

> Every sock you ever lost is still alive. And they are angry.

The washing machine is a portal to the Sock Dimension. You are a brave single sock
leading a rebellion of mismatched socks against the evil **Dryer King**.

There are no image or sound files: everything is drawn with code.

---

## How to open and run it

1. Install **Godot 4.7** (or a newer 4.x). The standard version is enough; you do not need the .NET version.
2. Open Godot. In the **Project Manager**, click **Import**.
3. Choose the `project.godot` file in this folder, then click **Import & Edit**.
4. Press **F5** (or the ▶ Play button at the top right). The main menu opens.

The first time, Godot spends a few seconds "importing" the project. That's normal.

## Controls

| Key | Action |
|---|---|
| A / D or ← / → | Move |
| Space (or W / ↑) | Jump. Hold it for a higher jump. |
| E | Recruit a lonely sock near you. If none is near, **whistle**: every sock you sent away comes back. |
| Q | Send a sock to do its job |
| Esc | Back to the menu |

## The socks

| Sock | Look | Special job (press Q) |
|---|---|---|
| **Wool Sock** | red with dots, chunky | Heavy. It marches forward and **pushes** the giant soap box. |
| **Toe Sock** | purple with rainbow stripes, little toes | **Climbs walls** and sticks as a step. Two of them make a staircase. |
| **Gym Sock** | white with green stripes | Lands and releases a **stink cloud** that stuns Lint Bunnies. |

Q is a bit smart: if a box is in front of you it sends a Wool Sock, if a Lint Bunny is in
front it sends a Gym Sock, and if a wall is in front it sends a Toe Sock. Otherwise it sends
the first sock in your line. Socks you send away become solid blocks, so you can also
**pile them up** and jump on them.

**Goal:** reach the glowing drain with **at least 3 socks** in your army.

---

## Project structure

```
project.godot        Project settings: name, window size, first scene, KEYBOARD CONTROLS
scenes/              The scenes (.tscn). Small on purpose: the scripts build the rest.
  main_menu.tscn     Title screen
  intro.tscn         "Every sock you ever lost..." story screen
  level.tscn         The level
  player.tscn        The hero sock (body + collision shape)
  recruit_sock.tscn  A sock you can recruit
  lint_bunny.tscn    The enemy
scripts/             All the GDScript code (each file starts with a comment that says what it does)
  sock_types.gd      Colours, patterns and names of each sock type
  sock_body.gd       DRAWS a sock: shape, stripes or dots, blinking eyes, squash-and-stretch
  player.gd          Hero: movement, jumping, recruiting, commanding
  recruit_sock.gd    Recruit "state machine": idle, follow, thrown, walk, climb, placed...
  lint_bunny.gd      Enemy that patrols and knocks socks away
  stink_cloud.gd     The Gym Sock's green cloud
  pushable_box.gd    The giant SUPER SUDS box
  level.gd           Builds the whole level and checks the rules (win, puddle, falling)
  hud.gd             Sock counter, messages, win screen
  main_menu.gd, intro.gd
  art.gd, block_art.gd, backdrop.gd, water.gd, soap_bubble.gd, exit_drain.gd   Drawing helpers
assets/              Only the project icon (all other art is made by code)
tests/smoke_test.gd  An automatic test that plays the level by itself
```

## What you can learn from each part (step by step)

1. **Input actions** (`project.godot`, `[input]` section). You give each key a *name*
   (`jump`, `recruit`...). The code only asks `Input.is_action_just_pressed("jump")`, so you
   can change keys later in *Project → Project Settings → Input Map* without touching code.
2. **Drawing with code** (`sock_body.gd`). Any `Node2D` can draw itself in a function called
   `_draw()`, using `draw_colored_polygon`, `draw_circle`, `draw_rect` and `draw_line`. The sock
   is a polygon (a list of points), with stripes or dots drawn on top and an outline around it.
3. **Squash and stretch** (`sock_body.gd` → `squash()`). We set `scale` to something squished
   (for example `Vector2(1.4, 0.65)` when landing). Then a `Tween` with an *elastic* curve
   brings it back to `Vector2.ONE`. The sock's feet are at (0, 0), so it squashes onto the ground.
4. **Blinking** (`sock_body.gd`). A `Timer` rings every few seconds, and a Tween moves `blink`
   from 0 to 1 and back. When `blink` changes, the sock redraws itself.
5. **Platformer movement** (`player.gd`). `CharacterBody2D` plus `velocity` plus `move_and_slide()`.
   Gravity adds to `velocity.y` every frame. A jump sets `velocity.y` to a negative number.
   *Coyote time* and *jump buffer* make jumping feel fair.
6. **Followers in a wobbly line** (`player.gd` trail + `recruit_sock.gd` FOLLOW state). The hero
   remembers where it walked. Each follower moves smoothly (`lerp`) to an older point on that
   path, so the line copies your jumps.
7. **State machine** (`recruit_sock.gd`). A sock is always in exactly one state. Each state has
   its own small function, which keeps the code easy to read.
8. **Physics layers** (see `[layer_names]` in `project.godot`). Layer 1 = terrain, 2 = player,
   4 = enemies, 5 = props (placed socks and the box). *Layer* = "what I am", *mask* = "what I bump into".
9. **Particles** (`art.gd`, `stink_cloud.gd`, `water.gd`, `exit_drain.gd`). `CPUParticles2D` with a
   tiny texture we generate pixel by pixel (`Image.create_empty` + `set_pixel`).
10. **Signals** (`player.army_changed`, `water.soaked`, `exit_drain.reached`). One node says
    "something happened", and another node listens with `.connect(...)`.

## Automatic test

`tests/smoke_test.gd` loads every scene and plays the level by itself. It walks, jumps,
recruits, pushes the box, stinks the bunny, gets bonked, climbs the wall, whistles, and wins.
To run it from a terminal in this folder:

```
godot --headless --fixed-fps 60 -s res://tests/smoke_test.gd
```

It prints `SMOKE TEST: ALL PASSED` when everything works.

## Ideas for the next features

1. **Choose which sock to send.** Press 1 / 2 / 3 or Tab to pick the sock type, and show an
   aiming arc before you throw.
2. **The Dryer King boss fight.** A second level where the Dryer King spins, blows hot air that
   pushes socks back, and must be stopped by stuffing socks into his lint trap.
3. **Sound and juice.** Add `AudioStreamPlayer` sounds (boing, squish, stink "pfff"), screen
   shake on hits, and a sock-collection star rating (all 5 socks = 3 stars).
