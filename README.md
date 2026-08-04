# Kona

A macOS menu bar app that prevents system sleep using configurable Presets.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Presets** - Keep your Mac awake for 15 min, 30 min, 1hr, 2hr, 4hr, 8hr, indefinitely, or on a schedule
- **Scheduled Presets** - Recurring day and time windows that activate automatically
- **Screen & Lock Control** - Independently allow screen dimming and system lock per preset
- **Sleep at the End** - Optionally put the Mac to sleep when a timed preset expires
- **Menu Bar Integration** - Quick toggle and remaining-time countdown from the menu bar (cup icon)
- **Launch Options** - Open at login and auto-activate a preset on launch
- **Automatic Updates** - Built-in updates via Sparkle, configurable in Settings

## Installation

### Download

Download the latest release from the [Releases](https://github.com/binoio/kona/releases) page, or from [the Kona site](https://binoio.github.io/kona/). Kona keeps itself up to date via Sparkle once installed.

### Build from Source

```bash
# Clone the repository
git clone https://github.com/binoio/kona.git
cd kona

# Build
swift build --configuration release

# Create app bundle
./Scripts/bundle.sh
```

The app bundle will be created at `build/Kona.app`.

## Usage

1. **Launch Kona** - The coffee cup icon appears in your menu bar
2. **Create a Preset** - Click the + button in the Kona Library and choose a duration
3. **Configure Settings**:
   - Toggle "Allow screen dim" to control display sleep
   - Toggle "Allow system lock" to control Mac lock
   - For timed presets, optionally enable "Sleep at the end"
   - For Scheduled presets, pick the days and time window
4. **Activate** - Click the power button next to a preset to enable it (Scheduled presets activate themselves)

### Menu Bar Icon

- ☕ **Filled cup** - A preset is active
- ☕ **Outline cup** - All presets disabled

## Development

### Requirements

- macOS 14 (Sonoma) or later
- Swift 5.9
- Xcode 15+ (optional, for IDE features)

### Build & Test

```bash
# Build debug
swift build

# Build release
swift build --configuration release

# Run all tests
swift test

# Run specific test
swift test --filter WakeStateManagerTests/testEnableWakeState
```

### Project Structure

```
kona/
├── Package.swift           # Swift Package Manager manifest
├── Sources/Kona/
│   ├── KonaApp.swift       # App entry point
│   ├── Controllers/        # WakeStateManager, SettingsManager, UpdaterViewModel
│   ├── Models/             # WakeState, Schedule, etc.
│   └── Views/              # SwiftUI views
├── Tests/KonaTests/        # Unit tests
├── Scripts/                # Bundle and release scripts
├── ReleaseNotes/           # Per-release notes (Markdown + appcast HTML)
├── docs/                   # GitHub Pages site and Sparkle appcast
└── Resources/              # App icon and assets
```

### Architecture

- **WakeStateManager** - Singleton managing preset lifecycle, persistence, and system sleep prevention
- **SettingsManager** - Singleton for app preferences and login item management
- **Sleep Prevention** - Uses `ProcessInfo.beginActivity()` with `idleDisplaySleepDisabled`
- **Updates** - Sparkle 2 with EdDSA-signed appcast served from GitHub Pages

## Scripts

| Script | Description |
|--------|-------------|
| `Scripts/bundle.sh` | Package the release build into `build/Kona.app` |
| `Scripts/release.sh` | Build, sign, notarize (App Store Connect API), update the appcast, and publish a GitHub release |
| `Scripts/generate_icon.swift` | Regenerate the app icon |

## Releasing

Shipping a release is three steps:

1. Bump `VERSION` (semver; must be newer than the latest tag)
2. Write `ReleaseNotes/Kona-X.Y.Z.md` (GitHub release body) and `ReleaseNotes/Kona-X.Y.Z.html` (embedded in the Sparkle appcast)
3. Run `Scripts/release.sh`

The script builds, signs (Developer ID, hardened runtime), notarizes and staples via the App Store Connect API, regenerates `docs/appcast.xml` with an EdDSA signature, publishes the GitHub release with the zip, and pushes the appcast — GitHub Pages then serves it to existing installs.

One-time machine prerequisites (already provisioned for this project): the Developer ID Application identity and Sparkle EdDSA private key in the login Keychain, a `kona-notary` notarytool keychain profile, and an authenticated `gh` CLI.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
