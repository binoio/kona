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
    var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        // Observe any changes to WakeStateManager (including item property changes)
        WakeStateManager.shared.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.setupMenuBar()
                self?.updateMenuBarIcon()
            }
        }.store(in: &cancellables)
        
        // Open at login logic handled in SettingsManager
        let settings = SettingsManager.shared
        if !settings.hasLaunched || settings.openNewDocumentOnLaunch {
            // Open new Wake State window or something
            // For now, perhaps open the library
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
        settings.hasLaunched = true
        
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
            if let indefinite = WakeStateManager.shared.wakeStates.first(where: { $0.name == "Indefinite" }) {
                indefiniteItem.state = indefinite.isEnabled ? .on : .off
            }
            menu.addItem(indefiniteItem)
            // Populate menu dynamically from saved wake states
            for state in WakeStateManager.shared.wakeStates where state.name != "Indefinite" {
                let item = NSMenuItem(title: state.name, action: #selector(toggleWakeState(_:)), keyEquivalent: "")
                item.state = state.isEnabled ? .on : .off
                item.representedObject = state.id
                menu.addItem(item)
            }
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit Kona", action: #selector(quitApp), keyEquivalent: "q"))

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
        if let button = statusItem?.button {
            let isEnabled = WakeStateManager.shared.currentEnabled != nil
            button.image = NSImage(systemSymbolName: isEnabled ? "cup.and.saucer.fill" : "cup.and.saucer", accessibilityDescription: isEnabled ? "Kona Enabled" : "Kona Disabled")
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func showSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.center()
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            settingsWindow?.title = "Kona Settings"
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}