# sfx.gd
# Sound effects and music, all made with MATH (no sound files!).
# A sound is just a long list of numbers that says where the speaker should be
# at each moment. We fill that list with simple waves:
#   square wave = beep-boop retro sound, sine = soft whistle, noise = hiss/thud.
# This is an autoload: any script can call  Sfx.play("jump").
extends Node

const RATE := 22050        # numbers (samples) per second for effects
const MUSIC_RATE := 11025  # lower quality is fine for the music (and faster to build)

var muted := false
var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A few players so several sounds can overlap.
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)

	#                       start Hz, end Hz, seconds, wave, volume
	_sounds["jump"] = _tone(320, 640, 0.14, "square", 0.22)
	_sounds["land"] = _tone(160, 60, 0.08, "noise", 0.3)
	_sounds["throw"] = _tone(520, 240, 0.13, "saw", 0.2)
	_sounds["stink"] = _tone(110, 50, 0.5, "noise", 0.35)
	_sounds["bonk"] = _tone(220, 70, 0.22, "square", 0.35)
	_sounds["stomp"] = _tone(180, 560, 0.12, "square", 0.3)
	_sounds["pop"] = _tone(900, 1500, 0.05, "sine", 0.3)
	_sounds["splash"] = _tone(900, 200, 0.3, "noise", 0.3)
	_sounds["zap"] = _tone(1400, 300, 0.16, "saw", 0.25)
	_sounds["whistle"] = _tone(1200, 1900, 0.25, "sine", 0.3)
	_sounds["snap"] = _tone(700, 100, 0.07, "noise", 0.45)
	_sounds["click"] = _tone(600, 800, 0.04, "square", 0.2)
	_sounds["recruit"] = _notes([660, 880], 0.09, "square", 0.25)
	_sounds["boss_hit"] = _notes([330, 247, 165], 0.12, "square", 0.35)
	_sounds["win"] = _notes([523, 659, 784, 1047], 0.13, "square", 0.3)

	_music = AudioStreamPlayer.new()
	_music.stream = _make_music()
	_music.volume_db = -16.0
	add_child(_music)
	_music.play()


func play(sound_name: String, pitch := 1.0) -> void:
	if not _sounds.has(sound_name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[sound_name]
	p.pitch_scale = pitch * randf_range(0.94, 1.06) # tiny random change = less boring
	p.play()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mute"):
		muted = not muted
		AudioServer.set_bus_mute(0, muted)


# ---------------- Making sounds ----------------

# One wave value between -1 and 1. "phase" grows as time passes.
func _wave(kind: String, phase: float) -> float:
	match kind:
		"square":
			return 1.0 if sin(phase) >= 0.0 else -1.0
		"saw":
			return fposmod(phase / TAU, 1.0) * 2.0 - 1.0
		"noise":
			return randf() * 2.0 - 1.0
		_:
			return sin(phase)


# A sound that slides from one pitch to another and fades out.
func _tone(from_hz: float, to_hz: float, seconds: float, kind: String, volume: float) -> AudioStreamWAV:
	var count := int(RATE * seconds)
	var bytes := PackedByteArray()
	bytes.resize(count * 2) # 16-bit sound = 2 bytes per sample
	var phase := 0.0
	for i in count:
		var k := float(i) / count
		phase += TAU * lerpf(from_hz, to_hz, k) / RATE
		var fade := minf(1.0, i / (0.004 * RATE)) * (1.0 - k)
		bytes.encode_s16(i * 2, int(clampf(_wave(kind, phase) * fade * volume, -1.0, 1.0) * 32767.0))
	return _to_stream(bytes, RATE)


# Several short notes one after another (a tiny jingle).
func _notes(freqs: Array, seconds_each: float, kind: String, volume: float) -> AudioStreamWAV:
	var per := int(RATE * seconds_each)
	var bytes := PackedByteArray()
	bytes.resize(per * freqs.size() * 2)
	var index := 0
	for hz in freqs:
		var phase := 0.0
		for i in per:
			phase += TAU * float(hz) / RATE
			var fade := minf(1.0, i / (0.004 * RATE)) * (1.0 - float(i) / per * 0.7)
			bytes.encode_s16(index * 2, int(_wave(kind, phase) * fade * volume * 32767.0))
			index += 1
	return _to_stream(bytes, RATE)


func _to_stream(bytes: PackedByteArray, rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream


# A bouncy 32-beat tune that loops forever. Notes are MIDI numbers
# (60 = middle C, +1 = one piano key higher). 0 = silence.
func _make_music() -> AudioStreamWAV:
	var melody := [
		[72, 1], [76, 1], [79, 1], [76, 1], [77, 1], [81, 1], [79, 2],
		[74, 1], [77, 1], [81, 1], [77, 1], [79, 1], [76, 1], [72, 2],
		[72, 1], [76, 1], [79, 1], [84, 1], [81, 1], [77, 1], [79, 2],
		[77, 1], [74, 1], [71, 1], [74, 1], [72, 2], [0, 2],
	]
	var bass := [48, 53, 55, 48, 48, 53, 55, 48] # one bass note every 4 beats
	var beat := int(MUSIC_RATE * 0.2)
	var total := beat * 32
	var bytes := PackedByteArray()
	bytes.resize(total * 2)

	var index := 0
	for note in melody:
		var hz := _midi_to_hz(note[0])
		var length: int = beat * int(note[1])
		var phase := 0.0
		for i in length:
			var value := 0.0
			if note[0] > 0:
				phase += TAU * hz / MUSIC_RATE
				var fade := minf(1.0, i / 40.0) * (1.0 - float(i) / length * 0.8)
				value = (1.0 if sin(phase) >= 0.0 else -1.0) * fade * 0.16
			# add the bass (a soft sine wave, short "plucks" on every beat)
			var bass_hz := _midi_to_hz(bass[(index / (beat * 4)) % bass.size()])
			var pluck := 1.0 - float(index % beat) / beat
			value += sin(TAU * bass_hz * index / MUSIC_RATE) * pluck * 0.2
			bytes.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
			index += 1

	var stream := _to_stream(bytes, MUSIC_RATE)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total
	return stream


func _midi_to_hz(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)
