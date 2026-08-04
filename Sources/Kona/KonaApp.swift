//
//  KonaApp.swift
//  Kona
//
//  Created by GitHub Copilot on 2025-12-26.
//

import SwiftUI
import Combine
import Sparkle

@main
struct KonaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var manager = WakeStateManager.shared

    // Duplicate/Delete act on the Library selection; without the window open
    // the user can't see what they'd be modifying
    private var canModifySelectedPreset: Bool {
        guard manager.libraryWindowVisible, let selected = manager.selectedWakeState else { return false }
        return selected.name != "Indefinite"
    }

    var body: some Scene {
        // The single Kona Library window; the AppDelegate captures its NSWindow
        // via WindowAccessor so the menu bar extra can re-present it after close.
        Window("Kona Library", id: "library") {
            LibraryView()
                .environmentObject(WakeStateManager.shared)
                .background(WindowAccessor { window in
                    guard let window = window else { return }
                    appDelegate.registerLibraryWindow(window)
                })
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(viewModel: appDelegate.updaterViewModel)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appDelegate.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {
                Button("New Preset...") {
                    appDelegate.showLibrary()
                    WakeStateManager.shared.showingNewPresetPrompt = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Duplicate") {
                    if canModifySelectedPreset, let selected = manager.selectedWakeState {
                        manager.duplicateWakeState(selected)
                    }
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(!canModifySelectedPreset)
                Button("Delete") {
                    if canModifySelectedPreset, let selected = manager.selectedWakeState {
                        manager.deleteWakeState(selected)
                    }
                }
                .keyboardShortcut(.delete)
                .disabled(!canModifySelectedPreset)
            }
            CommandGroup(before: .windowList) {
                Button("Kona Library") {
                    appDelegate.showLibrary()
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onWindow(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    var libraryWindow: NSWindow?
    var cancellables = Set<AnyCancellable>()
    var displayTimer: Timer?
    private var menuBarIconShowsEnabled: Bool?

    // Lazy and started manually so unit tests (which construct AppDelegate
    // directly) never spin up Sparkle's scheduled checks
    lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    lazy var updaterViewModel = UpdaterViewModel(updater: updaterController.updater)
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsManager.shared.applyDockIconVisibility()
        setupMenuBar()
        // Only start Sparkle when running from a real bundle with a feed
        // configured; skips xctest and `swift run`, which have no Info.plist keys
        if Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil {
            updaterController.startUpdater()
        }
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
            let checkForUpdatesItem = NSMenuItem(title: "Check for Updates…",
                                                 action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
                                                 keyEquivalent: "")
            checkForUpdatesItem.target = updaterController
            menu.addItem(checkForUpdatesItem)

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
           let enabledAt = state.enabledAt,
           let duration = state.duration.timeInterval {
            let elapsed = Date().timeIntervalSince(enabledAt)
            let remaining = max(0, duration - elapsed)
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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Kona lives in the menu bar; closing the Library window must not quit the app
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
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
            let settingsView = SettingsView(updaterViewModel: updaterViewModel)
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 540, height: 540),
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
            settingsWindow?.setContentSize(NSSize(width: 540, height: 540))
        }
        present(window: settingsWindow)
    }

    private func present(window: NSWindow?) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
