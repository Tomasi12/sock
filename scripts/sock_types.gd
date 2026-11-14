# sock_types.gd
# A tiny "data sheet" that describes every kind of sock.
# Other scripts load it with preload() and read the values from here,
# so if you want a pink Wool Sock you only change ONE place.
extends RefCounted

# An enum is a list of names that stand for numbers (HERO = 0, WOOL = 1, ...).
enum Kind { HERO, WOOL, TOE, GYM }

const DATA := {
	Kind.HERO: {
		"name": "The Last Sock",
		"body": Color("ffd23f"),
		"pattern": "stripes",
		"pattern_colors": [Color("ff8c42")],
		"cuff": Color("ffffff"),
		"half_width": 11.0,
	},
	Kind.WOOL: {
		"name": "Wool Sock",
		"body": Color("c0392b"),
		"pattern": "dots",
		"pattern_colors": [Color("fdebd0")],
		"cuff": Color("7b241c"),
		"half_width": 14.0, # wool socks are chunky
	},
	Kind.TOE: {
		"name": "Toe Sock",
		"body": Color("8e44ad"),
		"pattern": "stripes",
		"pattern_colors": [Color("ff6b6b"), Color("feca57"), Color("48dbfb"), Color("1dd1a1")],
		"cuff": Color("f8c6ff"),
		"half_width": 10.0,
	},
	Kind.GYM: {
		"name": "Gym Sock",
		"body": Color("f5f6fa"),
		"pattern": "gym",
		"pattern_colors": [Color("27ae60")],
		"cuff": Color("27ae60"),
		"half_width": 11.0,
	},
}
