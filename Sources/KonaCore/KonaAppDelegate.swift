//
//  KonaAppDelegate.swift
//  KonaCore
//

import SwiftUI
import Combine

/// Base app delegate shared by both distribution shells (Developer ID and
/// Mac App Store). Update-mechanism specifics are injected by subclasses via
/// the `updaterMenuItems()` and `settingsUpdatesSection()` hooks; the App
/// Store shell uses this class as-is.
open class KonaAppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    var libraryWindow: NSWindow?
    var cancellables = Set<AnyCancellable>()
    var displayTimer: Timer?
    private var menuBarIconShowsEnabled: Bool?

    public override init() {
        super.init()
    }

    // MARK: - Shell hooks

    /// Menu items appended to the status-item menu ahead of "Open Kona
    /// Library". The Developer ID shell contributes "Check for Updates…".
    open func updaterMenuItems() -> [NSMenuItem] { [] }

    /// Extra Settings form section. The Developer ID shell contributes the
    /// Sparkle "Updates" section; nil omits it entirely.
    open func settingsUpdatesSection() -> AnyView? { nil }

    // MARK: - Lifecycle

    open func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsManager.shared.applyDockIconVisibility()
        setupMenuBar()
        // Observe any changes to WakeStateManager (including item property changes)
        WakeStateManager.shared.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.setupMenuBar()
                self?.updateMenuBarIcon()
            }
        }.store(in: &cancellables)
        SettingsManager.shared.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.setupMenuBar()
                self?.updateMenuBarIcon()
            }
        }.store(in: &cancellables)

        // Open at login logic handled in SettingsManager
        let settings = SettingsManager.shared
        if !settings.hasLaunched {
            showLibrary()
        }
        settings.hasLaunched = true

        // Start a timer to update time remaining in the menu bar if needed
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMenuBarIcon()
        }

        // Activate launch wake state if configured
        if let launchId = settings.launchWakeStateId,
           let state = WakeStateManager.shared.wakeStates.first(where: { $0.id == launchId }),
           state.duration != .scheduled {
            WakeStateManager.shared.enableWakeState(state)
        }
    }

    func setupMenuBar() {
        if SettingsManager.shared.showMenuBarItem {
            // Reuse the existing status item — removing and re-adding it makes
            // the icon flicker in the menu bar; only the menu is rebuilt.
            if statusItem == nil {
                statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                menuBarIconShowsEnabled = nil
            }

            let menu = NSMenu()
            let indefiniteItem = NSMenuItem(title: "Indefinite Wake", action: #selector(toggleIndefiniteWake), keyEquivalent: "")
            indefiniteItem.target = self
            if let indefinite = WakeStateManager.shared.wakeStates.first(where: { $0.name == "Indefinite" }) {
                indefiniteItem.state = indefinite.isEnabled ? .on : .off
            }
            menu.addItem(indefiniteItem)
            // Populate menu dynamically from saved wake states
            for state in WakeStateManager.shared.wakeStates where state.name != "Indefinite" {
                // Scheduled presets activate on their schedule only: shown for status, not toggleable
                let action = state.duration == .scheduled ? nil : #selector(toggleWakeState(_:))
                let item = NSMenuItem(title: state.name, action: action, keyEquivalent: "")
                item.target = self
                item.state = state.isEnabled ? .on : .off
                item.representedObject = state.id
                menu.addItem(item)
            }
            menu.addItem(NSMenuItem.separator())
            for item in updaterMenuItems() {
                menu.addItem(item)
            }

            let openLibraryItem = NSMenuItem(title: "Open Kona Library", action: #selector(openLibraryFromMenu), keyEquivalent: "")
            openLibraryItem.target = self
            menu.addItem(openLibraryItem)

            let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettingsFromMenu), keyEquivalent: "")
            settingsItem.target = self
            menu.addItem(settingsItem)

            menu.addItem(NSMenuItem.separator())
            let quitItem = NSMenuItem(title: "Quit Kona", action: #selector(quitApp), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)

            statusItem?.menu = menu
            updateMenuBarIcon()
        } else {
            if let existing = statusItem {
                NSStatusBar.system.removeStatusItem(existing)
                statusItem = nil
            }
        }
    }

    @objc func toggleIndefiniteWake() {
        let manager = WakeStateManager.shared
        if let indefinite = manager.wakeStates.first(where: { $0.name == "Indefinite" }) {
            if indefinite.isEnabled {
                manager.disableWakeState(indefinite)
            } else {
                manager.enableWakeState(indefinite)
            }
            // Update menu bar icon
            updateMenuBarIcon()
        }
    }

    @objc func toggleWakeState(_ sender: NSMenuItem) {
        let manager = WakeStateManager.shared
        if let id = sender.representedObject as? UUID,
           let state = manager.wakeStates.first(where: { $0.id == id }),
           state.duration != .scheduled {
            if state.isEnabled {
                manager.disableWakeState(state)
            } else {
                manager.enableWakeState(state)
            }
            // Update menu
            setupMenuBar()
        }
    }

    func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }

        let current = WakeStateManager.shared.currentEnabled
        let isEnabled = current != nil
        // Only swap the image when the state actually changes — this runs every
        // second from the display timer and needless resets flicker the icon
        if menuBarIconShowsEnabled != isEnabled {
            button.image = NSImage(systemSymbolName: isEnabled ? "cup.and.saucer.fill" : "cup.and.saucer", accessibilityDescription: isEnabled ? "Kona Enabled" : "Kona Disabled")
            menuBarIconShowsEnabled = isEnabled
        }

        if SettingsManager.shared.showRemainingTimeInMenuBar,
           let state = current,
           let remaining = state.remainingTime() {
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            let seconds = Int(remaining) % 60

            let timeString: String
            if hours > 0 {
                timeString = String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else {
                timeString = String(format: "%d:%02d", minutes, seconds)
            }
            button.title = " \(timeString)"
        } else {
            button.title = ""
        }
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @objc func openLibraryFromMenu() {
        showLibrary()
    }

    @objc func openSettingsFromMenu() {
        showSettings()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Kona lives in the menu bar; closing the Library window must not quit the app
        false
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showLibrary()
        }
        return true
    }

    func registerLibraryWindow(_ window: NSWindow) {
        guard libraryWindow !== window else { return }
        libraryWindow = window
        // Keep our strong reference valid after the user closes the window;
        // NSWindow otherwise self-releases on close and the next show crashes.
        window.isReleasedWhenClosed = false
        WakeStateManager.shared.libraryWindowVisible = window.isVisible
        NotificationCenter.default.addObserver(self, selector: #selector(libraryWindowWillClose(_:)),
                                               name: NSWindow.willCloseNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(libraryWindowDidBecomeKey(_:)),
                                               name: NSWindow.didBecomeKeyNotification, object: window)
    }

    @objc private func libraryWindowWillClose(_ notification: Notification) {
        WakeStateManager.shared.libraryWindowVisible = false
    }

    @objc private func libraryWindowDidBecomeKey(_ notification: Notification) {
        WakeStateManager.shared.libraryWindowVisible = true
    }

    func showLibrary() {
        // The Library window is owned by the SwiftUI Window scene and registered
        // here via WindowAccessor; re-present that single window rather than
        // creating a second, differently-styled one.
        let window = libraryWindow ?? NSApp.windows.first { $0.title == "Kona Library" }
        present(window: window)
        if window != nil {
            WakeStateManager.shared.libraryWindowVisible = true
        }
    }

    func showSettings() {
        if settingsWindow == nil {
            let updatesSection = settingsUpdatesSection()
            let settingsView = SettingsView(updatesSection: updatesSection)
            let height: CGFloat = updatesSection == nil ? 440 : 540
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 540, height: height),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            // Keep our strong reference valid after the user closes the window;
            // NSWindow otherwise self-releases on close and the next show crashes.
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.center()
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            settingsWindow?.title = "Kona Settings"
            settingsWindow?.setContentSize(NSSize(width: 540, height: height))
        }
        present(window: settingsWindow)
    }

    private func present(window: NSWindow?) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
