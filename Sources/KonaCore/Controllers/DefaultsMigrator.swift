//
//  DefaultsMigrator.swift
//  Kona
//

import Foundation

/// One-time migration of user data from the pre-2.0 bundle identifier's
/// defaults domain (com.example.Kona) into the current domain.
public enum DefaultsMigrator {
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

    /// Shell entry point: migrate the legacy domain into standard defaults.
    /// A no-op inside the App Store sandbox (the legacy plist is unreadable
    /// there), which is fine — sandboxed installs start fresh.
    public static func migrateIfNeeded() {
        migrateIfNeeded(from: UserDefaults(suiteName: legacyDomain), to: .standard)
    }

    /// Copies known keys from the legacy domain if the target doesn't already
    /// have them. Idempotent via a marker key. The Developer ID app is not
    /// sandboxed, so UserDefaults(suiteName:) can read the old domain's plist.
    static func migrateIfNeeded(
        from source: UserDefaults?,
        to target: UserDefaults
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
