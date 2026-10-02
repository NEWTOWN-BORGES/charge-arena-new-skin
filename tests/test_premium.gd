extends SceneTree
## Regression checks for animated attachments, bounded VFX and graphics profiles.
const View = preload("res://scripts/indie_arena_view.gd")
const Rules = preload("res://scripts/arena_rules.gd")
const Video = preload("res://scripts/video_settings.gd")
const Audio = preload("res://scripts/combat_audio.gd")
const Skins = preload("res://scripts/skins.gd")
var failures = 0

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func _initialize(): call_deferred("run")

func run():
	var view = View.new()
	root.add_child(view)
	view.build()
	view.guide_enabled = false
	var rules = Rules.new()
	var video = Video.new()
	for skin in range(12) + range(100, 110):
		var pilot = view.build_player(View.CYAN, 0, skin)
		var body = pilot.get_node("Body")
		var valid = true
		for part in ["LegL", "LegR", "Gun", "Gun/Flash", "Head", "Arm"]:
			valid = valid and body.has_node(part)
		# A face on the head, or cut into a fused hull (trunk and head one piece); a hull may
		# also go without a face at all.
		var hull = String(View.Robots.recipe(skin).parts.torso).ends_with("_hull")
		valid = valid and (body.has_node("Head/Robot_screen") or body.has_node("Robot_screen") or hull)
		check(valid, "Skin %d keeps animated body, legs, weapon, muzzle and face" % skin)
		check(not body.has_node("Robot_outline"), "Skin %d has no ink hull in the studio look" % skin)
		var batch_ok = true
		for group in [body, body.get_node("LegL"), body.get_node("LegR"), body.get_node("Gun")]:
			var meshes = group.get_children().filter(func(n): return n is MeshInstance3D)
			batch_ok = batch_ok and meshes.size() <= 9
			for child in meshes:
				batch_ok = batch_ok and child.mesh.get_aabb().position.is_finite() and child.mesh.get_aabb().size.is_finite()
		check(batch_ok, "Skin %d merges its parts into bounded, finite meshes" % skin)
		pilot.free()
	# Switching profiles must be reversible, including glow, lighting and MSAA.
	var ivory = view.material(View.CREAM)
	for quality in [2, 0, 1, 2]:
		video.configure(60, quality, false, false)
		video.apply(root, view)
		if quality == 0:
			check(ivory.albedo_texture == null and ivory.roughness_texture == null and not ivory.normal_enabled and ivory.normal_texture == null and not ivory.clearcoat_enabled, "Light profile removes texture, normal, roughness-map and clearcoat cost after a refined profile")
		else:
			check(ivory.albedo_texture != null and ivory.albedo_texture.get_width() > 0 and ivory.albedo_texture.get_height() > 0, "Profile %d restores painted surface detail after the light profile" % quality)
			var rich_surfaces = not view.ArenaFinish.lean
			check(ivory.normal_enabled == rich_surfaces and (ivory.normal_texture != null) == rich_surfaces and (ivory.roughness_texture != null) == rich_surfaces, "Profile %d retains relief and roughness only when the GPU budget permits" % quality)
			check(ivory.clearcoat_enabled == (quality == 2) and ivory.clearcoat > 0.0 and ivory.clearcoat <= 1.0 and ivory.clearcoat_roughness > 0.0 and ivory.clearcoat_roughness <= 1.0, "Only the refined profile adds a bounded lacquer reflection")
		check(ivory.albedo_color.is_equal_approx(View.CREAM), "Profile %d preserves the base armour colour" % quality)
		var expected_aa = mini(Video.AA_LEVELS[quality], Viewport.MSAA_2X) if OS.has_feature("mobile") else Video.AA_LEVELS[quality]
		check(view.presentation_environment.glow_enabled == (quality == 2 and not OS.has_feature("mobile")) and root.msaa_3d == expected_aa, "Profile %d applies glow and anti-aliasing within the platform budget" % quality)
		var armour: MeshInstance3D = view.units[0].get_node("Body/Robot_paint")
		var colours = armour.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		check(armour.material_override.shader.resource_path.ends_with("robot_paint_low.gdshader") == (quality == 0) and colours != null and colours.size() > 0, "Profile %d preserves armour colours with the intended shader" % quality)
		var new_paint = view.material(Color(0.43, 0.38, 0.49 + quality * 0.03))
		check(new_paint.shading_mode == (BaseMaterial3D.SHADING_MODE_PER_VERTEX if quality == 0 else BaseMaterial3D.SHADING_MODE_PER_PIXEL), "Newly created materials respect the current profile")
		check(ivory.shading_mode == new_paint.shading_mode, "Profile %d relights existing materials the same way" % quality)
		for tick in range(120): view.update_state(rules, 0, 1.0 / 60.0)
		var nodes_before = view.get_child_count()
		for request in range(200):
			View.CombatFinish.card(view, Vector2.ZERO, 1.0, Color.CYAN, 0.2, request % 7)
		check(View.CombatFinish.active_count(view) == [8, 18, 28][quality], "Profile %d bounds simultaneous shock fronts" % quality)
		check(view.get_child_count() == nodes_before, "Impact burst creates no extra nodes")
		for tick in range(30): view.update_state(rules, 0, 1.0 / 60.0)
		check(View.CombatFinish.active_count(view) == 0 and (view.get_meta(View.CombatFinish.META) as Array).size() == 28, "All shock fronts return to the pool")
	# Weak GPUs keep painted plates at high detail while avoiding extra texture samples.
	# Exercise the cache in both directions so a downgrade cannot permanently strip detail.
	var prior_lean = view.ArenaFinish.lean
	view.ArenaFinish.lean = true
	view.set_quality(2)
	check(ivory.albedo_texture != null and ivory.roughness_texture == null and not ivory.normal_enabled and ivory.normal_texture == null, "Weak-GPU refinement keeps paint but removes normal and roughness-map sampling")
	view.ArenaFinish.lean = false
	view.set_quality(2)
	check(ivory.albedo_texture != null and ivory.roughness_texture != null and ivory.normal_enabled and ivory.normal_texture != null and ivory.clearcoat_enabled, "Refined surfaces recover relief and reflections after a GPU downgrade")
	view.ArenaFinish.lean = prior_lean
	view.set_quality(2)
	# Recycled beam cards must reset their basis and size when reused as impacts.
	View.CombatFinish.beam(view, Vector2.ZERO, Vector2.UP, 8.0, 0.5, Color.CYAN)
	view.update_state(rules, 0, 0.05)
	var beam = view.effects.back().node
	check(beam.scale.is_equal_approx(Vector3(0.5, 4.0, 1.0)), "Beam retains its path dimensions while animating")
	for tick in range(30): view.update_state(rules, 0, 1.0 / 60.0)
	var ring = View.CombatFinish.card(view, Vector2.ZERO, 1.2, Color.CYAN, 0.2)
	check(ring.scale.is_equal_approx(Vector3.ONE * 1.2) and ring.basis.y.is_equal_approx(Vector3(0, 0, -1.2)), "Reused card resets its transform after a beam")
	for tick in range(30): view.update_state(rules, 0, 1.0 / 60.0)
	View.CombatFinish.event(view, {"kind": "bloom", "p": rules.players[0].p, "team": 0, "bricks": [0, 1]}, rules)
	check(View.CombatFinish.active_count(view) > 0, "Healing has a visible premium effect")
	var clips_ok = not Audio.TRACKS.is_empty()
	for clip in Audio.TRACKS.values():
		clips_ok = clips_ok and clip is AudioStreamWAV and clip.data.size() > 0 and clip.get_length() > 0.08 and clip.loop_mode == AudioStreamWAV.LOOP_DISABLED
	check(clips_ok, "Every combat cue is loaded, contains audio and does not loop")
	# Coverage follows the playable kit and base skins, rather than a total that changes
	# when a solar alias or another ability is added.
	for power in Rules.Powers.CATALOG:
		check(Audio.TRACKS.has("ability_" + String(power.id)), "Ability %s has its own announcement cue" % power.id)
	for cue in ["power", "charging", "unleash", "goal", "boost", "shield", "ricochet", "metal", "blast", "laser_tick", "void_wave", "void_burst", "sentry"]:
		check(Audio.TRACKS.has(cue), "Combat feedback %s has a cue" % cue)
	for ultimate in Rules.Powers.ULTIMATES:
		var cue = "meteor" if ultimate.id == "meteors" else String(ultimate.id)
		check(Audio.TRACKS.has(cue), "Ultimate %s has discharge or impact audio" % ultimate.id)
	var base_skins: Dictionary = {}
	for skin in range(Skins.CATALOG.size()):
		base_skins[Skins.base_of(skin)] = true
	for skin in base_skins:
		var variants: Dictionary = {}
		for variant in range(3):
			var cue = "shot_%d_%d" % [skin, variant]
			if Audio.TRACKS.has(cue): variants[hash(Audio.TRACKS[cue].data)] = true
		check(variants.size() == 3, "Base skin %d has three distinct rotating shot recordings" % skin)
	for impact in ["hit", "break"]:
		var variants: Dictionary = {}
		for variant in range(3):
			var cue = "%s_%d" % [impact, variant]
			if Audio.TRACKS.has(cue): variants[hash(Audio.TRACKS[cue].data)] = true
		check(variants.size() == 3, "Impacts %s have three distinct recordings" % impact)
	var bus = Audio.prepare_bus()
	Audio.prepare_bus()
	var index = AudioServer.get_bus_index(bus)
	check(index > 0 and AudioServer.get_bus_effect_count(index) == 1 and AudioServer.get_bus_effect(index, 0) is AudioEffectHardLimiter, "Combat gets one dedicated limiter without changing Master")
	view.free()
	print("PREMIUM_RESULT failures=", failures)
	quit(failures)
