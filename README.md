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
├── Sources/KonaCore/       # Shared core: models, controllers, views, base app delegate
├── Sources/Kona/           # Developer ID shell (Sparkle auto-updates)
├── Sources/KonaAppStore/   # Mac App Store shell (sandboxed, no Sparkle)
├── Tests/KonaTests/        # Unit tests (target KonaCore)
├── Scripts/                # Bundle and release scripts for both channels
├── ReleaseNotes/           # Per-release notes (Markdown + appcast HTML)
├── docs/                   # GitHub Pages site and Sparkle appcast
└── Resources/              # App icon and assets
```

### Architecture

- **WakeStateManager** - Singleton managing preset lifecycle, persistence, and system sleep prevention
- **SettingsManager** - Singleton for app preferences and login item management
- **Sleep Prevention** - Uses `ProcessInfo.beginActivity()` with `idleDisplaySleepDisabled`
- **Updates** - Sparkle 2 with EdDSA-signed appcast served from GitHub Pages (Developer ID build only)
- **Distribution shells** - `KonaCore` holds all app logic; the `Kona` executable adds Sparkle for direct distribution, while `KonaAppStore` is the sandboxed Mac App Store variant. The App Store build triggers "Sleep at the end" via an Apple Event to System Events (`pmset` is unavailable in the sandbox) and has no Updates section in Settings

## Scripts

| Script | Description |
|--------|-------------|
| `Scripts/bundle.sh` | Package the release build into `build/Kona.app` (Developer ID + Sparkle) |
| `Scripts/release.sh` | Build, sign, notarize (App Store Connect API), update the appcast, and publish a GitHub release |
| `Scripts/bundle-mas.sh` | Package the sandboxed App Store build into `build/mas/Kona.app` |
| `Scripts/release-mas.sh` | Sign with Apple Distribution, build the installer pkg, and upload to App Store Connect |
| `Scripts/generate_icon.swift` | Regenerate the app icon |

## Releasing

Shipping a release is three steps:

1. Bump `VERSION` (semver; must be newer than the latest tag)
2. Write `ReleaseNotes/Kona-X.Y.Z.md` (GitHub release body) and `ReleaseNotes/Kona-X.Y.Z.html` (embedded in the Sparkle appcast)
3. Run `Scripts/release.sh`

The script builds, signs (Developer ID, hardened runtime), notarizes and staples via the App Store Connect API, regenerates `docs/appcast.xml` with an EdDSA signature, publishes the GitHub release with the zip, and pushes the appcast — GitHub Pages then serves it to existing installs.

One-time machine prerequisites (already provisioned for this project): the Developer ID Application identity and Sparkle EdDSA private key in the login Keychain, a `kona-notary` notarytool keychain profile, and an authenticated `gh` CLI.

### Mac App Store channel (disabled by feature flag)

The App Store shell is developed dual-track but not released: default builds produce only the Developer ID app, and `release-mas.sh` refuses to run. Everything App Store–specific is gated behind `KONA_MAS=1`:

```bash
# Build and package the App Store shell during development
KONA_MAS=1 swift build -c release
KONA_MAS=1 bash Scripts/bundle-mas.sh
```

When the channel goes live, run `KONA_MAS=1 Scripts/release-mas.sh` after the Developer ID release to ship the same version to the App Store. The release script builds the sandboxed `KonaAppStore` shell, signs it with the Apple Distribution identity and `Scripts/KonaAppStore.entitlements`, embeds the provisioning profile, packages an installer pkg, and uploads it to App Store Connect (then select the build and submit for review there). The App Store release owns no git tag — versioning follows the Developer ID release.

One-time prerequisites for this channel (not yet provisioned): Apple Distribution and Mac Installer Distribution certificates, a Mac App Store provisioning profile for `io.binoio.Kona` at `Scripts/KonaAppStore.provisionprofile` (git-ignored), an App Store Connect API key with the App Manager role (`KONA_ASC_KEY_ID`/`KONA_ASC_ISSUER_ID`, `.p8` in `~/.appstoreconnect/private_keys/`), and an app record for `io.binoio.Kona` in App Store Connect. Note: the sandboxed build's "Sleep at the end" uses an Apple Events entitlement exception that App Review may question; if rejected, remove the entitlement and hide the toggle in the App Store shell.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
