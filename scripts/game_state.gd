# game_state.gd
# An "autoload": Godot creates this node once when the game starts and keeps it
# alive in every scene. Any script can use it by its name: GameState.
# It remembers which level you are playing and how many stars you earned,
# and it saves that to a file so your progress survives closing the game.
extends Node

const Levels = preload("res://scripts/levels.gd")
const Art = preload("res://scripts/art.gd")

const SAVE_PATH := "user://last_sock_save.json"
const LEVEL_SCENE := "res://scenes/level.tscn"
const MAP_SCENE := "res://scenes/world_map.tscn"
const STORY_SCENE := "res://scenes/intro.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"

const WORLD_NAMES := {
	1: "World 1: The Drum",
	2: "World 2: Ironing Board Plains",
	3: "World 3: The Dryer Depths",
	4: "World 4: The Closet of Doom",
}

# The story screen shown when a new world starts: [big text, small text, sock kind].
const WORLD_STORIES := {
	2: ["Big Fluff is flat!\nOn to the Ironing Board Plains.", "The air smells of hot metal. Something is crackling...", 1],
	3: ["The Iron Baron is cold.\nThe Dryer Depths are next.", "Deep down, a king of lint and heat is waiting.", 3],
	4: ["The Dryer King is defeated...\nbut who stole the socks FIRST?", "From the closet comes a hungry humming. Count Suckula, the vacuum cleaner,\nhas been eating socks for years. And he is still hungry.\n\nA Rubber Sock waits for you there. Boing!", 4],
}

var levels: Array = []        # every level of the game, in order
var current := 0              # index of the level being played
var stars := {}               # level id -> best number of stars (1 to 3)
var seen_intro := false
var saving_enabled := true    # the automatic test turns this off
var save_path := SAVE_PATH    # (the tests point this at a throw-away file)
var story := {}               # text for the story screen (see intro.gd)


func _ready() -> void:
	levels = Levels.build_all()
	load_game()


# Runs when the game closes.
func _exit_tree() -> void:
	Art.clear_cache()


func current_level() -> Dictionary:
	return levels[current]


func is_unlocked(index: int) -> bool:
	# A level opens when the level before it is finished.
	return index == 0 or stars.has(levels[index - 1]["id"])


func stars_for(index: int) -> int:
	return int(stars.get(levels[index]["id"], 0))


func total_stars() -> int:
	var sum := 0
	for value in stars.values():
		sum += int(value)
	return sum


func has_next() -> bool:
	return current + 1 < levels.size()


# Called by the level when you win.
func complete(star_count: int) -> void:
	var id: String = levels[current]["id"]
	stars[id] = maxi(int(stars.get(id, 0)), star_count)
	save_game()


func go_to_level(index: int) -> void:
	current = index
	get_tree().change_scene_to_file(LEVEL_SCENE)


func go_next() -> void:
	var story := next_story()
	if has_next():
		current += 1
		if story.is_empty():
			go_to_level(current)
		else:
			show_story(story["big"], story["small"], LEVEL_SCENE, story["kind"])
	else:
		show_story(story["big"], story["small"], MENU_SCENE, story["kind"])


# What to tell the player after the current level: a world story when the
# next level is in a new world, the ending after the last level, else nothing.
func next_story() -> Dictionary:
	if not has_next():
		return {
			"big": "Count Suckula is clogged forever.\nEvery lost sock is free!",
			"small": "Somewhere, a human opens a drawer and finds a matching pair.\nFor the first time in years.\n\nThank you for playing!",
			"kind": 0,
		}
	var now: int = levels[current]["world"]
	var next: int = levels[current + 1]["world"]
	if next != now and WORLD_STORIES.has(next):
		var s: Array = WORLD_STORIES[next]
		return {"big": s[0], "small": s[1], "kind": s[2]}
	return {}


# Show the story screen with some text, then go to another scene.
func show_story(big_text: String, small_text: String, next_scene: String, sock_kind: int) -> void:
	story = {"big": big_text, "small": small_text, "next": next_scene, "kind": sock_kind}
	get_tree().change_scene_to_file(STORY_SCENE)


func save_game() -> void:
	if not saving_enabled:
		return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"stars": stars, "seen_intro": seen_intro}))


func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	# A save file can be broken (half written, edited by hand...). We check
	# everything we read, so a bad file can never crash the game.
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		return
	var saved = json.data.get("stars", {})
	stars = {}
	if saved is Dictionary:
		for id in saved:
			var value = saved[id]
			if (value is float or value is int) and value >= 1 and _has_level(str(id)):
				stars[str(id)] = mini(int(value), 3)
	var seen = json.data.get("seen_intro", false)
	seen_intro = seen is bool and seen


func _has_level(id: String) -> bool:
	for level in levels:
		if level["id"] == id:
			return true
	return false


func reset_progress() -> void:
	stars = {}
	seen_intro = false
	save_game()
