//
//  KonaApp.swift
//  Kona
//
//  Developer ID shell: KonaCore plus Sparkle auto-updates.
//

import SwiftUI
import KonaCore

@main
struct KonaApp: App {
    @NSApplicationDelegateAdaptor(SparkleAppDelegate.self) var appDelegate

    init() {
        // Must run before any singleton reads defaults, or pre-2.0 data
        // (presets, settings) under com.example.Kona would be ignored.
        // The shared manager is first touched later, when the scene body runs.
        DefaultsMigrator.migrateIfNeeded()
    }

    var body: some Scene {
        KonaLibraryWindow(appDelegate: appDelegate)
            .commands {
                CommandGroup(after: .appInfo) {
                    CheckForUpdatesView(viewModel: appDelegate.updaterViewModel)
                }
                KonaCommands(appDelegate: appDelegate)
            }
    }
}
