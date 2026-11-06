extends SceneTree
# Test security features: save signing, anti-tampering, package integrity

const SecurityGuard = preload("res://systems/security/SecurityGuard.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# 1. Test hash calculation
	var h1 = SecurityGuard.generate_hash("bricks=50;owned=blast")
	var h2 = SecurityGuard.generate_hash("bricks=50;owned=blast")
	var h3 = SecurityGuard.generate_hash("bricks=999999;owned=blast")
	assert(h1 == h2, "Hash is deterministic")
	assert(h1 != h3, "Different content produces different hash")

	# 2. Test ConfigFile signing and verification
	var cfg = ConfigFile.new()
	cfg.set_value("powers", "bricks", 100)
	cfg.set_value("powers", "owned", ["blast", "rapid"])
	SecurityGuard.sign_config(cfg, "powers")

	assert(cfg.has_section("_security"), "Signature section added")
	assert(SecurityGuard.verify_config(cfg, "powers"), "Clean config verifies successfully")

	# 3. Simulate tamper (player editing bricks to 999999 via hex editor or text editor)
	cfg.set_value("powers", "bricks", 999999)
	assert(not SecurityGuard.verify_config(cfg, "powers"), "Tampered config fails verification")

	# 4. Test package integrity
	assert(SecurityGuard.verify_package_integrity("org.chargearena.game"), "Official game package accepted")
	assert(SecurityGuard.verify_package_integrity("org.chargearena.teste"), "Official test package accepted")
	assert(not SecurityGuard.verify_package_integrity("com.cloned.chargearena"), "Cloned package rejected")
	assert(not SecurityGuard.verify_package_integrity("org.chargearena.modded"), "Modded package rejected")

	print("PASS SECURITY: save signing, anti-tamper, anti-clone package check")
	quit(0)

