//
//  KonaApp.swift
//  Kona
//
//  Created by GitHub Copilot on 2025-12-26.
//

import SwiftUI
import Combine

@main
struct KonaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(WakeStateManager.shared)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appDelegate.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {
                Button("New Wake State") {
                    let manager = WakeStateManager.shared
                    let newState = WakeState(
                        name: "Untitled",
                        options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true)
                    )
                    manager.addWakeState(newState)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Duplicate") {
                    if let selected = WakeStateManager.shared.selectedWakeState, selected.name != "Indefinite" {
                        WakeStateManager.shared.duplicateWakeState(selected)
                    }
                }
                .keyboardShortcut("d", modifiers: .command)
                Button("Delete") {
                    if let selected = WakeStateManager.shared.selectedWakeState, selected.name != "Indefinite" {
                        WakeStateManager.shared.deleteWakeState(selected)
                    }
                }
                .keyboardShortcut(.delete)
            }
        }
        
        // Kona Library window
        Window("Kona Library", id: "library") {
            LibraryView()
                .environmentObject(WakeStateManager.shared)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    var libraryWindow: NSWindow?
    var cancellables = Set<AnyCancellable>()
    var displayTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
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
           let state = WakeStateManager.shared.wakeStates.first(where: { $0.id == launchId }) {
            WakeStateManager.shared.enableWakeState(state)
        }
    }
    
    func setupMenuBar() {
        if SettingsManager.shared.showMenuBarItem {
            // Remove previous status item to prevent duplicates
            if let existing = statusItem {
                NSStatusBar.system.removeStatusItem(existing)
                statusItem = nil
            }
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

            let menu = NSMenu()
            let indefiniteItem = NSMenuItem(title: "Indefinite Wake", action: #selector(toggleIndefiniteWake), keyEquivalent: "")
            indefiniteItem.target = self
            if let indefinite = WakeStateManager.shared.wakeStates.first(where: { $0.name == "Indefinite" }) {
                indefiniteItem.state = indefinite.isEnabled ? .on : .off
            }
            menu.addItem(indefiniteItem)
            // Populate menu dynamically from saved wake states
            for state in WakeStateManager.shared.wakeStates where state.name != "Indefinite" {
                let item = NSMenuItem(title: state.name, action: #selector(toggleWakeState(_:)), keyEquivalent: "")
                item.target = self
                item.state = state.isEnabled ? .on : .off
                item.representedObject = state.id
                menu.addItem(item)
            }
            menu.addItem(NSMenuItem.separator())
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
           let state = manager.wakeStates.first(where: { $0.id == id }) {
            if state.isEnabled {
                manager.disableWakeState(state)
            } else {
                manager.enableWakeState(state)
            }
            // Update menu
            setupMenuBar()
        }
    }
    
    @objc func newWakeState() {
        let manager = WakeStateManager.shared
        let newState = WakeState(
            name: "Untitled",
            options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true)
        )
        manager.addWakeState(newState)
    }
    
    func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }
        
        let current = WakeStateManager.shared.currentEnabled
        let isEnabled = current != nil
        button.image = NSImage(systemSymbolName: isEnabled ? "cup.and.saucer.fill" : "cup.and.saucer", accessibilityDescription: isEnabled ? "Kona Enabled" : "Kona Disabled")
        
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

    func showLibrary() {
        if let existingWindow = NSApp.windows.first(where: { window in
            window !== settingsWindow && window.contentViewController != nil
        }) {
            present(window: existingWindow)
            return
        }

        if libraryWindow == nil {
            let libraryView = ContentView()
                .environmentObject(WakeStateManager.shared)

            libraryWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 540),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            libraryWindow?.center()
            libraryWindow?.contentView = NSHostingView(rootView: libraryView)
            libraryWindow?.title = "Kona Library"
            libraryWindow?.setFrameAutosaveName("KonaLibraryWindow")
        }

        present(window: libraryWindow)
    }

    func showSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 540, height: 440),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.center()
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            settingsWindow?.title = "Kona Settings"
            settingsWindow?.setContentSize(NSSize(width: 540, height: 440))
        }
        present(window: settingsWindow)
    }

    private func present(window: NSWindow?) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
