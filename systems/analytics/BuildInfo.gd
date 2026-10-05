extends RefCounted
# Which game this is: version, build, flavour and store. Kept in step with
# export_presets.cfg (tests/regression/test_analytics.gd checks it).

const VERSION = "3.47.0"
const BUILD = 76

# lab (open_test), playtest, store (a store build) or dev (editor and tests).
static func flavor() -> String:
	if OS.has_feature("open_test"):
		return "lab"
	if OS.has_feature("playtest"):
		return "playtest"
	if store() != "":
		return "store"
	return "dev"

# The store the APK was built for: one APK per store, tagged at export.
static func store() -> String:
	for tag in ["store_galaxy", "store_google", "store_huawei"]:
		if OS.has_feature(tag):
			return tag.trim_prefix("store_")
	return ""

# Production data only from store builds; LAB, playtest and dev builds go elsewhere.
static func production() -> bool:
	return flavor() == "store"

static func platform() -> String:
	return OS.get_name().to_lower()

static func device_model() -> String:
	return OS.get_model_name()

static func os_version() -> String:
	return OS.get_version()
