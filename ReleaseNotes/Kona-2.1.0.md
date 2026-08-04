# Kona 2.1.0

Kona 2.1 makes Scheduled presets dependable across launches and shows their countdown in the menu bar.

## New

- **Scheduled countdown** — with "Show remaining time in menu bar" enabled, an active Scheduled preset now counts down to the end of today's window, just like timed presets

## Fixed

- **Scheduled presets activate at launch** — launching Kona inside a scheduled window now activates the preset immediately. Previously a preset could appear checked in the menu after a relaunch while nothing actually kept the Mac awake
- Stale "enabled" checkmarks from a previous run are cleared at launch; presets only show as active when they truly hold a sleep assertion

## Under the hood

- Kona's app logic now lives in a shared core with the Developer ID app as a thin shell around it, paving the way for an experimental Mac App Store variant (in development, not yet released)

## Notes

- Requires macOS 14 (Sonoma) or later
