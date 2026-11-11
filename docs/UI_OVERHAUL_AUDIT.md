# Charge Arena — interface audit and reconstruction plan

## Scope and method

Audited the checked-out Godot project before changing interface code. The project is a Godot 4.7.1 mobile game. The two supplied specifications agree on a fixed command hub, abandon the TikTok-style vertical feed, and call for a staged interface-wide redesign while preserving real game systems and saves.

## Actual scene structure

`scenes/main.tscn` contains only one authored node: `ChargeArena` (`Node3D`) with `scripts/main.gd` attached. It does not contain authored menu scenes or reusable UI scenes.

At runtime, `scripts/main.gd` creates the persistent `ArenaView` 3D presentation, then a `CanvasLayer` containing `GameHUD` (`scripts/ui/game_hud.gd`). The HUD constructs menus, overlays, dialogs, and match HUD elements in GDScript. `Lobby` (`scripts/ui/lobby.gd`) is another runtime-created control used for profile, currency, navigation, and mode access.

## UI inventory

| Area | Current builder/component | Existing behavior and data dependency |
|---|---|---|
| Main command/menu screen | `GameHUD.build_menu()`, `Lobby` | Story/campaign entry, mode access, level preview, settings, profile and currency |
| Pause and match result | `GameHUD.build_pause_menu()`, match HUD drawing | Resume, exit, replay, next match/level, result actions |
| Hangar and pilots | `GameHUD.build_skins_menu()`, `build_skin_viewer()` | Real pilot catalog, preview, selection, music preview |
| Cosmetic workshop | `GameHUD.build_workshop()` | Paint, projectile color and brick cosmetics; real ownership/equipment |
| Powers shop/loadout | `GameHUD.build_powers_menu()` | Existing catalog, prices, wallet, ownership, two equipped powers and pilot ultimate |
| Campaign and arenas | `GameHUD.build_levels_menu()`, `build_map_picker()` | Campaign level sequence, real unlock/progress, map preview and selection |
| Boss campaign | `GameHUD.build_bosses_menu()` | Existing story entries, difficulty, recap and launch actions |
| Quick match | `GameHUD.build_map_picker()` and main menu controls | Difficulty, map selection and quick-match start |
| PvP | `GameHUD.build_pvp_menu()` | Local duel/squad, host/join, room codes and current online availability |
| Settings | `GameHUD.build_video_menu()` | Audio, graphics, controls, language, privacy, vibration, battery and HUD controls |
| Privacy/consent | `GameHUD.build_privacy_prompt()` | Consent stored through the existing analytics/privacy system |
| Tutorial | `tutorial_overlay.gd` and HUD tutorial steps | Existing lobby, shop, and match walkthroughs |
| Unlock feedback | `unlock_notice.gd` | Queue of unlock, power, cosmetic and affordability notifications |
| Feel tuning | `feel_panel.gd` | LAB/game-feel tuning backed by existing settings |
| Credits | `GameHUD.open_credits()` | Credits overlay and dismissal |
| In-match HUD | `GameHUD._draw()` and drawing helpers | Score, timer, pilot and wall life, powers, controls, status and match feedback |

## Navigation and business logic

`GameHUD` emits typed signals for navigation and actions. `scripts/main.gd` connects them to the actual game controllers: match start/resume/end, campaign progression, online networking, difficulty, settings, skins, powers, cosmetics, and music. Return/back actions are implemented by the relevant overlay close methods and the Escape handler.

Purchases use the existing game data. `scripts/gameplay/powers.gd` checks ownership and currency before charging and equipping powers. `scripts/progression/cosmetics.gd` checks cosmetic ownership and pays from the same power-shop wallet. `scripts/main.gd` receives purchase signals, saves the resulting data, and refreshes the HUD. Campaign, skins, marathon, game/video settings, and cosmetics each retain their own existing progression or preferences implementation.

## Relevant code inventory

- `scripts/main.gd` — scene runtime, arena/HUD creation, UI signal routing, gameplay, saves and services.
- `scripts/ui/game_hud.gd` — programmatic UI, overlays, match HUD and drawing helpers (approximately 5,000 lines).
- `scripts/ui/lobby.gd` — main lobby profile, currency, navigation, and mode actions.
- `scripts/ui/ui_kit.gd` — shared colors, panel/button styles, labels and button interaction.
- `scripts/ui/ui_scroll.gd` — touch scrolling support for overlay content.
- `scripts/ui/tutorial_overlay.gd`, `unlock_notice.gd`, `feel_panel.gd` — supporting overlays.
- `scripts/gameplay/powers.gd`, `scripts/progression/{campaign,cosmetics,marathon,skins}.gd`, `scripts/settings/{game_settings,video_settings,game_feel}.gd`, and `scripts/network/online.gd` — systems the interface must continue to call.

## Backup

Before interface edits, a source backup was created under `.qa/ui-overhaul-backup/`. It contains the current UI scripts, main controller and scene, project/export configuration, and the purchase, campaign, skin, cosmetic, marathon, and settings scripts used by the interface.

## Design system and staged implementation

Use the supplied Charge Arena palette: Deep Space `#071329`, Arena Blue `#0755A5`, Energy Cyan `#32C8E7`, Charge Gold `#F2B943`, Interface Dark `#172431`, Primary Text `#F0F4F8`, Warning Red `#E65B64`. The command hub remains one stable screen with a featured Story operation, a two-column grid for the other modes, a persistent 3D character stage, and fixed bottom destinations. No feed-style page snapping or vertical mode pages.

Implement in stages: shared theme/components; command hub; power shop and loadout; hangar and cosmetics; campaign, arenas and modes; settings, modals, notifications, tutorial and results; then responsive and functional validation. Keep purchase and progression rules in their existing systems.
