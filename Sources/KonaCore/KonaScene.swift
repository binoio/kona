//
//  KonaScene.swift
//  KonaCore
//
//  The Library window scene and main-menu commands shared by both
//  distribution shells. Each shell composes these in its @main App and adds
//  its own update-mechanism commands.
//

import SwiftUI

/// The single Kona Library window; the app delegate captures its NSWindow
/// via WindowAccessor so the menu bar extra can re-present it after close.
public struct KonaLibraryWindow: Scene {
    let appDelegate: KonaAppDelegate

    public init(appDelegate: KonaAppDelegate) {
        self.appDelegate = appDelegate
    }

    public var body: some Scene {
        Window("Kona Library", id: "library") {
            LibraryView()
                .environmentObject(WakeStateManager.shared)
                .background(WindowAccessor { window in
                    guard let window = window else { return }
                    appDelegate.registerLibraryWindow(window)
                })
        }
    }
}

/// Menu commands common to both shells: Settings, New Preset,
/// Duplicate/Delete, and the Window-menu Library entry.
public struct KonaCommands: Commands {
    let appDelegate: KonaAppDelegate
    @ObservedObject var manager: WakeStateManager

    public init(appDelegate: KonaAppDelegate) {
        self.appDelegate = appDelegate
        _manager = ObservedObject(wrappedValue: WakeStateManager.shared)
    }

    // Duplicate/Delete act on the Library selection; without the window open
    // the user can't see what they'd be modifying
    private var canModifySelectedPreset: Bool {
        guard manager.libraryWindowVisible, let selected = manager.selectedWakeState else { return false }
        return selected.name != "Indefinite"
    }

    public var body: some Commands {
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
