extends RefCounted
## Local display preferences; never change the authoritative 60 Hz simulation.
const FPS_OPTIONS = [30, 60, 90]
const QUALITY_NAMES = ["Leve", "Equilibrado", "Refinado"]
# Compatibility does not support screen-space FXAA. Use actual MSAA for silhouettes.
# 8x cost more than the whole rest of the frame on a phone screen (2340 x 1080) and dragged a
# Galaxy S23 from 90 to under 20 FPS in a busy match; 4x keeps the edges clean for far less.
const AA_LEVELS = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
const SCREEN_AA = [Viewport.SCREEN_SPACE_AA_DISABLED, Viewport.SCREEN_SPACE_AA_DISABLED, Viewport.SCREEN_SPACE_AA_DISABLED]
const EFFECT_LIMITS = [20, 48, 96]
# The 3D always renders at full resolution. On Android the Compatibility renderer draws the
# root viewport straight to the screen, so a 3D scale below 1 did not upscale: the arena came
# out smaller, and shrank again every time the automatic adjustment stepped down mid-match.
const RENDER_SCALES = [1.0, 1.0, 1.0]
# Half-second windows of steady frames before stepping back up; doubled every time a step up
# had to be undone, so a phone that cannot hold it does not see-saw.
const RECOVER_WINDOWS = 12
const CONFIG_PATH = "user://video_settings.cfg"
var fps = 60
# A phone starts on the performance profile; a PC has no reason to.
var quality = (1 if OS.has_feature("mobile") else 2) if OS.has_feature("open_test") else (0 if OS.has_feature("mobile") else 2)
var vsync = true
var show_fps = false
var runtime_scale = 0.72
var runtime_fps = 60
var smooth_hud = true
var low_windows = 0
var stable_windows = 0
var recover_after = RECOVER_WINDOWS
var recovered = false

func load_preferences(path: String = CONFIG_PATH) -> void:
	var config = ConfigFile.new()
	if config.load(path) != OK:
		return
	var saved_quality = int(config.get_value("video", "quality", 0))
	# Existing Android installs used a much heavier profile. Migrate once so an
	# update cannot preserve the setting that caused stalls on entry-level phones.
	if OS.has_feature("mobile") and int(config.get_value("video", "performance_version", 0)) < 2:
		saved_quality = 0
	if OS.has_feature("open_test") and int(config.get_value("video", "presentation_version", 0)) < 3:
		saved_quality = 1 if OS.has_feature("mobile") else 2
	configure(int(config.get_value("video", "fps", 60)), saved_quality, bool(config.get_value("video", "vsync", true)), bool(config.get_value("video", "show_fps", false)))

func configure(new_fps: int, new_quality: int, sync: bool, counter: bool) -> void:
	# A setting saved by an older build may still say 120; it lands on 60.
	fps = new_fps if new_fps in FPS_OPTIONS else 60
	quality = clampi(new_quality, 0, QUALITY_NAMES.size() - 1)
	vsync = sync
	show_fps = counter
	runtime_scale = RENDER_SCALES[quality]
	runtime_fps = fps
	low_windows = 0
	stable_windows = 0
	recover_after = RECOVER_WINDOWS
	recovered = false

func save_preferences(path: String = CONFIG_PATH) -> Error:
	var config = ConfigFile.new()
	config.set_value("video", "fps", fps)
	config.set_value("video", "quality", quality)
	config.set_value("video", "vsync", vsync)
	config.set_value("video", "show_fps", show_fps)
	config.set_value("video", "performance_version", 2)
	config.set_value("video", "presentation_version", 3)
	return config.save(path)

func apply(viewport: Viewport, arena) -> void:
	runtime_fps = fps
	runtime_scale = RENDER_SCALES[quality]
	Engine.max_fps = runtime_fps
	viewport.msaa_3d = AA_LEVELS[quality]
	viewport.screen_space_aa = SCREEN_AA[quality]
	viewport.use_debanding = quality > 0
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = runtime_scale
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	arena.effect_limit = EFFECT_LIMITS[quality]
	# The light profile drops per-primitive antialiasing in the HUD: on a mid-range phone
	# those 182 soft edges were more than half of the draw calls in a frame.
	smooth_hud = quality > 0
	arena.trail_interval = [0.11, 0.06, 0.035][quality]
	arena.set_quality(quality)

func adapt(viewport: Viewport, measured_fps: float, force_mobile: bool = false) -> bool:
	if (not OS.has_feature("mobile") and not force_mobile) or fps < 60:
		return false
	var expected = float(runtime_fps)
	if measured_fps < expected * 0.84:
		low_windows += 1
		stable_windows = 0
	else:
		low_windows = 0
		stable_windows += 1
	# Three seconds of trouble, not one burst of a power, before anything is given away.
	var required_windows = 6 if quality > 0 else 3
	if low_windows < required_windows:
		# Keeping up again: win back what was given away, frames first, then resolution.
		# Without this a short heavy moment left the phone at 30 FPS for the rest of the
		# session.
		if stable_windows >= recover_after:
			stable_windows = 0
			recovered = true
			if runtime_fps < fps:
				runtime_fps = mini(fps, 60 if runtime_fps < 60 else fps)
				Engine.max_fps = runtime_fps
				return true
		return false
	low_windows = 0
	if recovered:
		# The last step up did not hold: wait longer before the next one.
		recovered = false
		recover_after = mini(recover_after * 2, 120)
	# Equilibrado and Refinado preserve their exact visual profile and give up frames
	# instead: 90 -> 60 -> 30. With 120 gone from the options, the ladder reaches all the
	# way down rather than stopping at 60 on a phone that cannot hold it.
	if quality > 0:
		# Only the frame rate moves: nothing in the picture may change during a match (the
		# phone's renderer changed the light when the multisampling was dropped mid-game).
		if runtime_fps > 60:
			runtime_fps = 60
		elif runtime_fps > 30 and measured_fps < 60 * 0.6:
			# 30 only for a phone that cannot even reach the high forties: a busy moment that
			# dips to 50 should not cost the whole match half its frames.
			runtime_fps = 30
		else:
			return false
		Engine.max_fps = runtime_fps
		return true
	# Leve is the performance profile for weaker phones: a stable 45/30 FPS fallback.
	if runtime_fps > 45:
		# 45 divides a 90 Hz display evenly. On a 60 Hz panel it causes uneven
		# pacing, so go straight to the stable 30 FPS fallback.
		var refresh_rate = DisplayServer.screen_get_refresh_rate()
		runtime_fps = 45 if refresh_rate >= 85.0 else 30
	elif runtime_fps > 30:
		runtime_fps = 30
	else:
		return false
	Engine.max_fps = runtime_fps
	return true
