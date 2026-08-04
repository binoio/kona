# Kona 2.0.0

Kona 2.0 overhauls presets, consolidates the Library, and adds automatic updates.

## New

- **Duration-first presets** — create a preset by picking its duration up front; presets are named for their duration ("30 Minutes", with "(1)", "(2)" for duplicates)
- **Scheduled presets** — a new preset type that activates automatically on chosen days and time windows; scheduled presets can't be toggled manually since their schedule is in charge
- **Sleep at the end** — timed presets can optionally put the Mac to sleep when their timer expires
- **Automatic updates** — Kona now updates itself via Sparkle; you'll be asked once whether to check automatically, and everything is configurable in Settings → Updates

## Changed

- One consolidated Kona Library window with a stable title; the selected preset's name shows inside the details pane. Reopen it anytime with ⌘0 or from the menu bar extra
- Preset renaming and in-place duration editing removed — the duration is the name
- Remaining time in the menu bar is now shown by default
- New presets disallow screen dim and system lock by default
- Duplicate and Delete are disabled while the Library window is closed

## Fixed

- Reopening Settings after closing it no longer crashes the app
- Closing the Library window no longer quits Kona
- The menu bar icon no longer flickers when clicking between presets

## Notes

- Your existing presets and settings are migrated automatically
- Requires macOS 14 (Sonoma) or later
