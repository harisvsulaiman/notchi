# Changelog

> This is a personal fork of [notchi](https://github.com/sk-ruban/notchi) by [@harisvsulaiman](https://github.com/harisvsulaiman).

## Unreleased

### Added
- **Pill display mode** — Floating capsule UI as an alternative to the notch. Draggable to any screen position, with configurable corner placement (bottom-left / bottom-right) in settings.
- **Planning state** — New task state when Claude enters plan mode, with dedicated sprite, animation, and color indicator.
- **Multi-session sprites** — Collapsed pill and notch show up to 2 tamagotchi sprites side by side, taking turns stepping forward as if fighting for attention.
- **On-device emotion analysis** — Analyze Claude's emotional tone using NLEmbedding (no API key required).
- **Startup sound** — Plays a sound on app launch.
- **Pac-man walk animation** — Header sprite uses a pac-man style walk cycle.

### Changed
- Extracted `PanelToolbar` as a shared component for notch and pill views.
- Redesigned settings panel with inline screen/sound pickers and segmented pickers for display mode and pill corner.
- User prompt bubbles use an iMessage-style bubble shape.
- Removed unnecessary dividers from expanded panel.

### Fixed
- `toggleLaunchAtLogin` correctly maps register/unregister.
- Sprites no longer overlap when multiple sessions are active.
