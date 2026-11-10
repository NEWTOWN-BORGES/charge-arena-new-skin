extends RefCounted
# The game's language: Portuguese, English, French, Spanish or Italian.
#
# The Portuguese text is the key (gettext style): every Label and Button translates
# itself through Godot's auto-translation, and text drawn by hand goes through tr().
# A string with no translation yet simply stays in Portuguese. The tables live in
# res://localization/*.csv (columns: keys,pt,en,fr,es,it) and are checked by
# tools/i18n/check_translations.py.

const LANGUAGES = ["pt", "en", "fr", "es", "it"]
const NAMES = {"pt": "Português", "en": "English", "fr": "Français", "es": "Español", "it": "Italiano"}
const FALLBACK = "en"

static var path = "user://locale.cfg"

# First launch defaults to English for international itch.io release (or saved choice).
# Automated runs without a screen stay in Portuguese, the language the tests read.
static func detect() -> String:
	if DisplayServer.get_name() == "headless":
		return "pt"
	return FALLBACK

static func saved() -> String:
	var config = ConfigFile.new()
	if config.load(path) != OK:
		return ""
	var code = String(config.get_value("locale", "language", ""))
	return code if LANGUAGES.has(code) else ""

static func current() -> String:
	var locale = TranslationServer.get_locale().substr(0, 2)
	return locale if LANGUAGES.has(locale) else FALLBACK

# Called once at start: the player's choice, or the detected language.
static func apply_startup() -> String:
	var code = saved()
	if code == "":
		code = detect()
	TranslationServer.set_locale(code)
	return code

# A choice from Options. Returns the previous language.
static func choose(code: String) -> String:
	var before = current()
	if not LANGUAGES.has(code):
		return before
	var config = ConfigFile.new()
	config.set_value("locale", "language", code)
	config.save(path)
	TranslationServer.set_locale(code)
	return before
