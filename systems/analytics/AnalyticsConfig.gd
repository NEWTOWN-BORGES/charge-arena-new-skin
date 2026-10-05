extends RefCounted
# Where statistics go. Only public, write-only project keys belong here (PostHog's
# "project API key" is made to ship inside apps). Never a personal or admin key.
#
# Empty keys mean nothing is sent: the game behaves the same, statistics stay off.

const PROVIDER = "posthog"
const HOST = "https://eu.i.posthog.com"
# Store builds: the production project.
const API_KEY = "phc_yWawtxAEcEbtYkqkP5Ng8dPMqknUGqBeM5j42Rou2HsT"
# LAB, playtest and development builds go to the same project, tagged by build_flavor
# (lab, playtest, dev): dashboards for real players filter on build_flavor = store.
const DEV_API_KEY = API_KEY
const FLUSH_SECONDS = 30.0
const BATCH_SIZE = 20
# The privacy policy page (Firebase Hosting). Shown in the consent screen and Options.
const PRIVACY_URL = ""
