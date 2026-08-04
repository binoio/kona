//
//  DefaultsMigrator.swift
//  Kona
//

import Foundation

/// One-time migration of user data from the pre-2.0 bundle identifier's
/// defaults domain (com.example.Kona) into the current domain.
enum DefaultsMigrator {
    static let migrationKey = "didMigrateFromComExampleKona"
    static let legacyDomain = "com.example.Kona"
    static let migratedKeys = [
        "wakeStates",
        "showMenuBarItem",
        "hideDockIcon",
        "showRemainingTimeInMenuBar",
        "openAtLogin",
        "hasLaunched",
        "launchWakeStateId"
    ]

    /// Copies known keys from the legacy domain if the target doesn't already
    /// have them. Idempotent via a marker key. The app is not sandboxed, so
    /// UserDefaults(suiteName:) can read the old domain's plist directly.
    static func migrateIfNeeded(
        from source: UserDefaults? = UserDefaults(suiteName: legacyDomain),
        to target: UserDefaults = .standard
    ) {
        guard !target.bool(forKey: migrationKey) else { return }
        defer { target.set(true, forKey: migrationKey) }
        guard let source = source else { return }
        for key in migratedKeys where target.object(forKey: key) == nil {
            if let value = source.object(forKey: key) {
                target.set(value, forKey: key)
            }
        }
    }
}
