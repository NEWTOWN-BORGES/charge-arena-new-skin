extends RefCounted
# The player's choices, kept apart per purpose: gameplay statistics (opt-in, asked on
# first launch) and error reports (on, with a notice, and a switch to turn them off).
# There is no advertising or marketing in the game; those stay off and are not asked.

# Raise this when the privacy policy changes in a way that matters: the game asks again.
const POLICY_VERSION = 1

var path = "user://privacy.cfg"
var decided = false
var analytics = false
var errors = true
var policy_version = 0

func load_choices() -> void:
	var config = ConfigFile.new()
	if config.load(path) != OK:
		return
	decided = bool(config.get_value("privacy", "decided", false))
	analytics = bool(config.get_value("privacy", "analytics", false))
	errors = bool(config.get_value("privacy", "errors", true))
	policy_version = int(config.get_value("privacy", "policy_version", 0))

func save_choices() -> int:
	var config = ConfigFile.new()
	config.set_value("privacy", "decided", decided)
	config.set_value("privacy", "analytics", analytics)
	config.set_value("privacy", "errors", errors)
	config.set_value("privacy", "policy_version", policy_version)
	return config.save(path)

# The first-launch question: not answered yet, or answered under an older policy.
func needs_prompt() -> bool:
	return not decided or policy_version < POLICY_VERSION

func choose(allow_analytics: bool, allow_errors: bool) -> void:
	decided = true
	analytics = allow_analytics
	errors = allow_errors
	policy_version = POLICY_VERSION
	save_choices()

# Statistics only once the player said yes under the current policy.
func analytics_allowed() -> bool:
	return decided and analytics and policy_version >= POLICY_VERSION

# Reports are on by default, but only after the first-launch screen has said so.
func errors_allowed() -> bool:
	return decided and errors
