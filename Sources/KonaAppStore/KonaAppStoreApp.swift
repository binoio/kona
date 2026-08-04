//
//  KonaAppStoreApp.swift
//  KonaAppStore
//
//  Mac App Store shell: sandboxed, no Sparkle (the App Store delivers
//  updates), and a sandbox-compatible "Sleep at the end" trigger.
//

import SwiftUI
import KonaCore

@main
struct KonaAppStoreApp: App {
    @NSApplicationDelegateAdaptor(KonaAppDelegate.self) var appDelegate

    init() {
        // Runs before the shared manager is first touched (scene body).
        // No-op inside the sandbox container, but harmless and keeps the
        // shells' startup identical.
        DefaultsMigrator.migrateIfNeeded()
        // pmset's power-management call is denied inside the sandbox; ask
        // System Events to sleep instead (NSAppleEventsUsageDescription +
        // apple-events entitlement, user grants Automation consent once).
        WakeStateManager.shared.triggerSystemSleep = {
            var error: NSDictionary?
            let script = NSAppleScript(source: "tell application \"System Events\" to sleep")
            script?.executeAndReturnError(&error)
            if let error = error {
                print("Failed to trigger system sleep via System Events: \(error)")
            }
        }
    }

    var body: some Scene {
        KonaLibraryWindow(appDelegate: appDelegate)
            .commands {
                KonaCommands(appDelegate: appDelegate)
            }
    }
}
