extends RefCounted
## Every number that decides how a shot feels, in one place: recoil, muzzle flash, trail,
## impacts, destruction, hit-stop, camera, haptics and the mix. Presentation only — nothing
## here reaches the rules, so tuning it can never change a match. The LAB build's tuning
## panel edits these live and saves them to user://game_feel.cfg.
const CONFIG_PATH = "user://game_feel.cfg"

# The hierarchy: each level gets more sound, more light, more camera and more haptics than
# the one below. If everything is strong, nothing is.
enum Level { AMBIENT, SHOT, IMPACT, DESTROY, POWER, ULTIMATE, DECISIVE }

const DEFAULTS = {
	# Recoil: SNAP to the peak in one frame, hold a hair, return with a small overshoot.
	"fire_recoil_strength": 0.19,
	"fire_recoil_peak": 0.05,
	"fire_return_duration": 0.15,
	"fire_body_kick": 0.045,
	# Muzzle: a white-hot core for a couple of frames, then the coloured bloom and sparks.
	"muzzle_flash_duration": 0.07,
	"muzzle_spark_amount": 5,
	# Sizes in arena units, tuned for the match camera where a pilot is a few centimetres
	# tall on a phone.
	"muzzle_flash_size": 1.5,
	"impact_flash_size": 1.0,
	"trail_length": 1.0,
	# Impacts and breaks.
	"impact_particle_amount": 6,
	"destruction_particle_amount": 10,
	# Visual hit-stop in seconds: the effects hold still, the match never does.
	"hitstop_destroy": 0.028,
	"hitstop_last_brick": 0.055,
	"hitstop_goal": 0.09,
	# Camera: strength per level (before the player's own Off / Low / Full setting).
	"camera_fire_strength": 0.012,
	"camera_impact_strength": 0.02,
	"camera_destroy_strength": 0.07,
	"camera_power_strength": 0.16,
	"camera_ultimate_strength": 0.26,
	"camera_last_brick_strength": 0.22,
	"camera_goal_strength": 0.34,
	# Haptics in milliseconds and strength 0-1, per category.
	"haptic_fire_ms": 7,
	"haptic_fire_strength": 0.1,
	"haptic_destroy_ms": 18,
	"haptic_destroy_strength": 0.3,
	"haptic_power_ms": 24,
	"haptic_power_strength": 0.34,
	"haptic_goal_ms": 70,
	"haptic_goal_strength": 0.85,
	# Audio: small pitch and level variation keeps a thousand shots from sounding pasted.
	"audio_pitch_variation": 0.025,
	"audio_volume_variation": 0.8,
	"ultimate_duck_db": -7.0,
	"ultimate_duck_seconds": 0.18,
}

# What each level may do. Camera strengths are looked up from the table above.
const LEVELS = {
	Level.SHOT: {"camera": "camera_fire_strength", "shake_time": 0.09, "shake_hz": 34.0},
	Level.IMPACT: {"camera": "camera_impact_strength", "shake_time": 0.1, "shake_hz": 30.0},
	Level.DESTROY: {"camera": "camera_destroy_strength", "shake_time": 0.16, "shake_hz": 26.0},
	Level.POWER: {"camera": "camera_power_strength", "shake_time": 0.24, "shake_hz": 20.0},
	Level.ULTIMATE: {"camera": "camera_ultimate_strength", "shake_time": 0.36, "shake_hz": 16.0},
	Level.DECISIVE: {"camera": "camera_goal_strength", "shake_time": 0.42, "shake_hz": 14.0},
}

var values: Dictionary = DEFAULTS.duplicate()
# "Effects intensity" in the options: 1.0 Full, 0.6 Reduced. Scales particles and light,
# never the hierarchy between them.
var intensity = 1.0

func get_value(key: String) -> float:
	return float(values.get(key, DEFAULTS.get(key, 0.0)))

func count(key: String, quality: int) -> int:
	# Particle budgets per profile: every profile keeps FIRE → IMPACT → DESTROY readable.
	return maxi(1, int(round(get_value(key) * [0.5, 0.8, 1.0][clampi(quality, 0, 2)] * intensity)))

func load_values(path: String = CONFIG_PATH) -> void:
	var config = ConfigFile.new()
	if config.load(path) != OK:
		return
	for key in DEFAULTS:
		values[key] = config.get_value("feel", key, DEFAULTS[key])

func save_values(path: String = CONFIG_PATH) -> Error:
	var config = ConfigFile.new()
	for key in values:
		config.set_value("feel", key, values[key])
	return config.save(path)

func reset() -> void:
	values = DEFAULTS.duplicate()
