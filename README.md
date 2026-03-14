# Kona

A macOS menu bar app that prevents system sleep using configurable "Wake States."

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Wake States** - Create named profiles to keep your Mac awake with custom settings
- **Flexible Durations** - Choose from 15 min, 30 min, 1hr, 2hr, 4hr, 8hr, or indefinite
- **Screen & Lock Control** - Independently control screen dimming and system lock
- **Scheduling** - Set recurring schedules with specific days and time windows
- **Menu Bar Integration** - Quick toggle from the menu bar (cup icon)
- **Launch Options** - Open at login and auto-activate wake states on launch

## Installation

### Download

Download the latest release from the [Releases](https://github.com/mabino/kona/releases) page.

### Build from Source

```bash
# Clone the repository
git clone https://github.com/mabino/kona.git
cd kona

# Build
swift build --configuration release

# Create app bundle
./Scripts/build.sh
```

The app bundle will be created at `.build/arm64-apple-macosx/release/Kona.app`.

## Usage

1. **Launch Kona** - The coffee cup icon appears in your menu bar
2. **Create a Wake State** - Click the + button to add a new wake state
3. **Configure Settings**:
   - Set a duration or choose indefinite
   - Toggle "Allow Screen Dim" to control display sleep
   - Toggle "Allow System Lock" to control Mac lock
   - Optionally set a recurring schedule
4. **Activate** - Click the power button next to a wake state to enable it

### Menu Bar Icon

- ☕ **Filled cup** - A wake state is active
- ☕ **Outline cup** - All wake states disabled

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
│   ├── Controllers/        # WakeStateManager, SettingsManager
│   ├── Models/             # WakeState, Schedule, etc.
│   └── Views/              # SwiftUI views
├── Tests/KonaTests/        # Unit tests
├── Scripts/                # Build, test, and release scripts
└── Resources/              # App icon and assets
```

### Architecture

- **WakeStateManager** - Singleton managing wake state lifecycle, persistence, and system sleep prevention
- **SettingsManager** - Singleton for app preferences and login item management
- **Sleep Prevention** - Uses `ProcessInfo.beginActivity()` with `idleDisplaySleepDisabled`

## Scripts

| Script | Description |
|--------|-------------|
| `build.sh` | Build release and create app bundle |
| `test.sh` | Run test suite |
| `notarize.sh` | Code sign and notarize for distribution |
| `release.sh` | Build, notarize, and publish release to GitHub |

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
