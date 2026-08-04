//
//  SparkleAppDelegate.swift
//  Kona
//

import SwiftUI
import Sparkle
import KonaCore

final class SparkleAppDelegate: KonaAppDelegate {
    // Lazy and started manually so unit tests (which construct the delegate
    // directly) never spin up Sparkle's scheduled checks
    lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    lazy var updaterViewModel = UpdaterViewModel(updater: updaterController.updater)

    override func applicationDidFinishLaunching(_ notification: Notification) {
        super.applicationDidFinishLaunching(notification)
        // Only start Sparkle when running from a real bundle with a feed
        // configured; skips xctest and `swift run`, which have no Info.plist keys
        if Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil {
            updaterController.startUpdater()
        }
    }

    override func updaterMenuItems() -> [NSMenuItem] {
        let checkForUpdatesItem = NSMenuItem(title: "Check for Updates…",
                                             action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
                                             keyEquivalent: "")
        checkForUpdatesItem.target = updaterController
        return [checkForUpdatesItem]
    }

    override func settingsUpdatesSection() -> AnyView? {
        AnyView(UpdatesSectionView(viewModel: updaterViewModel))
    }
}
