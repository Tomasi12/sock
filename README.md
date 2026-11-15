# The Last Sock

A funny 2D side-view game made with **Godot 4** and **GDScript**.

> Every sock you ever lost is still alive. And they are angry.

The washing machine is a portal to the Sock Dimension. You are a brave single sock
leading a rebellion of mismatched socks against the evil **Dryer King**.

There are no image or sound files: all art and all sounds are made with code.

**The game:** 3 worlds, 18 stages (15 levels + 3 bosses), 5 kinds of enemies, star ratings
and saved progress.

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
| E | Recruit a lonely sock near you. If none is near, **whistle**: every sock that was in your army comes back. |
| Q | **Hold** to aim (a line shows where the sock goes), **let go** to send it |
| Tab, or 1 / 2 / 3 | Pick which sock Q sends: 1 = Wool, 2 = Toe, 3 = Gym. Press the same number again for AUTO. |
| R | Restart the level |
| Esc | Back to the level map |
| M | Sound on / off |

## The socks

| Sock | Look | Special job (Q) |
|---|---|---|
| **Wool Sock** | red with dots, chunky | Marches forward. **Pushes** the giant soap box. **Soaks up Static Sparks.** |
| **Toe Sock** | purple with rainbow stripes, little toes | **Climbs walls** and sticks as a step. You can jump up through it. |
| **Gym Sock** | white with green stripes | Lands and makes a **stink cloud**: stuns bunnies and Snappers, defeats Moths. |

On AUTO, Q picks for you: box or Spark ahead → Wool, other enemy ahead → Gym, wall ahead → Toe.
Socks you send become solid blocks, so you can also **pile them up** and jump on them.

## The enemies and how to beat them

| Enemy | What it does | How to beat it |
|---|---|---|
| **Lint Bunny** | Hops left and right. Knocks a sock out of your army. | Stink cloud makes it dizzy, then **jump on it**. |
| **Clothespin Snapper** | Hangs on a clothesline and drops on you. | **Stop when it wiggles** so it misses. It is stuck in the floor for a moment: jump on it. |
| **Static Spark** | Floats back and forth and zaps you and thrown socks. | Send a **Wool Sock**. Or jump over it / run under it. |
| **Hot Iron** | Sees you, heats up and charges. Too hot to stomp. | **Water.** Stand on the other side of a puddle and let it charge in. |
| **Moth** | Swoops down and chews the last sock in your line. | **Stink cloud** (moths hate Gym Socks), or jump on it. |

## The bosses

| Boss | How to beat it |
|---|---|
| **Big Fluff** (World 1) | Stink cloud, then jump on its head. 3 times. It calls little bunnies. |
| **The Iron Baron** (World 2) | Jump on the buttons so his charge misses. He crashes into the wall and is dizzy: throw a sock at him. 3 times. |
| **The Dryer King** (World 3) | He spits enemies, blows hot air (hold D to push back), then his door **opens**: throw a sock inside. 5 times. |

## Stars

Each stage gives up to 3 stars: **1** for finishing, **1** for bringing *every* sock to the
drain, **1** for a *flawless* run (never bonked, chewed or soaked). 54 stars in total.
Your progress is saved automatically.

---

## Project structure

```
project.godot        Project settings: window size, first scene, KEYBOARD CONTROLS, autoloads
scenes/              The scenes (.tscn). Small on purpose: the scripts build the rest.
  main_menu.tscn  intro.tscn (story)  world_map.tscn (level select)  level.tscn
  player.tscn  recruit_sock.tscn
scripts/
  game_state.gd      AUTOLOAD. Which level you play, your stars, saving to a file.
  sfx.gd             AUTOLOAD. All sounds and the music, made with math.
  levels.gd          THE CAMPAIGN: every level as a short list of pieces.   <-- add levels here
  level_builder.gd   The level pieces (floor, puddle, wall, enemies...) with fair sizes.
  level.gd           Builds a level from its description and checks the rules.
  player.gd          Hero: movement, jumping, recruiting, picking, aiming, sending.
  recruit_sock.gd    Recruit "state machine": idle, follow, thrown, walk, climb, placed...
  sock_types.gd      Colours, patterns and names of each sock type.
  sock_body.gd       DRAWS a sock: shape, pattern, blinking eyes, squash-and-stretch.
  enemy.gd           Parent script of all enemies: stun, stomp, defeat, hurting the hero.
  lint_bunny.gd  snapper.gd  spark.gd  iron.gd  moth.gd        The five enemies.
  boss_fluff.gd  boss_iron.gd  boss_dryer.gd                   The three bosses.
  hud.gd             Counter, picked sock, timer, messages, boss bar, win screen.
  world_map.gd  main_menu.gd  intro.gd  star_row.gd            Menus.
  art.gd  block_art.gd  backdrop.gd  water.gd  soap_bubble.gd  exit_drain.gd
  stink_cloud.gd  pushable_box.gd  lint_bunny_art.gd  iron_art.gd   Drawing and props.
assets/              Only the project icon (everything else is made by code).
tests/               Automatic tests: small checks, a mechanics test, and a robot player.
run_tests.ps1        Runs all the tests.
```

## How to add your own level

Open `scripts/levels.gd`. A level is a list of pieces, for example:

```gdscript
static func _my_level() -> Dictionary:
	var b := Builder.new("4-1", "My First Level", 1)   # id, name, world (1, 2 or 3 = colours)
	b.start()
	b.socks([W, T])          # a Wool Sock and a Toe Sock to recruit
	b.tip("Hello! This is a sign.")
	b.bunnies(2, 600)        # 2 Lint Bunnies on 600 px of floor
	b.box_puddle()           # soap box + wide puddle (needs Wool)
	b.flat(150)
	b.wall(200)              # a wall (needs a Toe Sock)
	b.iron_trap()            # small puddle with a Hot Iron behind it
	b.drain()                # the exit, always last
	return b.finish(2)       # you must bring 2 socks
```

Then add `_my_level()` to the list in `build_all()`. Every piece is explained in
`scripts/level_builder.gd`. The builder checks your design: if you put a wall before the
player can have a Toe Sock, the automatic test tells you.

## What you can learn from each part

1. **Input actions** (`project.godot`, `[input]`). Each key has a *name* (`jump`, `recruit`...).
   The code only asks `Input.is_action_just_pressed("jump")`, so you can change keys in
   *Project → Project Settings → Input Map* without touching code.
2. **Drawing with code** (`sock_body.gd`). Any `Node2D` can draw itself in `_draw()` with
   `draw_colored_polygon`, `draw_circle`, `draw_rect` and `draw_line`.
3. **Squash and stretch** (`sock_body.gd` → `squash()`). Set `scale` to something squished,
   then a `Tween` with an *elastic* curve brings it back.
4. **Platformer movement** (`player.gd`). `CharacterBody2D` + `velocity` + `move_and_slide()`.
   *Coyote time* and *jump buffer* make jumping feel fair.
5. **Followers in a wobbly line** (`player.gd` trail + `recruit_sock.gd`). The hero remembers
   where it walked; each follower moves smoothly (`lerp`) to an older point on that path.
6. **State machines** (`recruit_sock.gd`, every enemy). A thing is always in exactly one state,
   and each state has its own small piece of code.
7. **Inheritance** (`enemy.gd`). All enemies start with `extends "res://scripts/enemy.gd"` and
   only change what is different. `super()` runs the parent's version of a function.
8. **Autoloads** (`game_state.gd`, `sfx.gd`). Nodes that live for the whole game and can be
   used from any script by name.
9. **Data-driven levels** (`levels.gd`, `level_builder.gd`). A level is *data* (a Dictionary),
   and one script (`level.gd`) can build any of them.
10. **Sound from math** (`sfx.gd`). A sound is a list of numbers. Square waves, sine waves and
    noise are enough for retro effects and a small tune.
11. **Saving** (`game_state.gd`). `FileAccess` + `JSON` write your stars to `user://`.
12. **Physics layers** (`[layer_names]` in `project.godot`). *Layer* = "what I am",
    *mask* = "what I bump into".

## Automatic tests

There are three tests in `tests/`. Run them after you change something:

```
powershell -File run_tests.ps1
```

(If your Godot is not installed with Steam, set the path first:
`$env:GODOT = "C:\path\to\godot.exe"`.) Or run one test by hand:

```
godot --headless --fixed-fps 60 res://tests/unit_test.tscn
```

| Test | What it does | Prints when all is fine |
|---|---|---|
| `unit_test` | About 180 small checks: level design rules, sounds and keys, saving (also with a broken save file), menus, and "what if" cases (Q with no socks, a sock falling into a hole, two Toe Socks at once...). | `UNIT TEST: ALL PASSED` |
| `smoke_test` | Loads all 18 stages, then checks every mechanic, every enemy and all three bosses. | `SMOKE TEST: ALL PASSED` |
| `campaign_bot` | A robot player. It plays all 15 normal levels from start to drain with the **real keys** (no cheating) and must bring every sock. If the bot can do it, the level is possible. | `CAMPAIGN BOT: ALL PASSED` |

When a test finds a problem it prints a line starting with `FAIL` that says what went wrong.
The bot also prints how long each level took and how many times it got bonked.

## Ideas for what to add next

1. **A fourth world** with a new sock type (for example a Rubber Sock that bounces you high).
2. **Secret socks** hidden off the main path, and a reward for collecting all 54 stars.
3. **A pause menu** with volume sliders and key rebinding.
