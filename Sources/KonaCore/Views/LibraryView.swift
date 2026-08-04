//
//  LibraryView.swift
//  Kona
//
//  Created by GitHub Copilot on 2025-12-26.
//

import SwiftUI

struct SidebarRow: View {
    @ObservedObject var state: WakeState
    @EnvironmentObject var manager: WakeStateManager

    var body: some View {
        HStack {
            if state.duration == .scheduled {
                // Scheduled presets activate on their schedule only — no manual toggle
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(state.isEnabled ? .accentColor : .secondary)
                    .help("Activates automatically on its schedule")
            } else {
                Button(action: {
                    if state.isEnabled {
                        manager.disableWakeState(state)
                    } else {
                        manager.enableWakeState(state)
                    }
                }) {
                    Image(systemName: state.isEnabled ? "power.circle.fill" : "power.circle")
                        .foregroundColor(state.isEnabled ? .accentColor : .primary)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("enableButton-\(state.id.uuidString)")
            }

            Text(state.name)
            Spacer()
            if state.name != "Indefinite" {
                Button(action: {
                    manager.duplicateWakeState(state)
                }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                Button(action: {
                    manager.deleteWakeState(state)
                }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

struct NewPresetSheet: View {
    @EnvironmentObject var manager: WakeStateManager
    @Environment(\.dismiss) private var dismiss
    @State private var duration: WakeDuration = .thirtyMinutes

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Preset")
                .font(.headline)
            Picker("Duration", selection: $duration) {
                ForEach(WakeDuration.allCases, id: \.self) { d in
                    Text(d.rawValue).tag(d)
                }
            }
            .pickerStyle(.radioGroup)
            if duration == .scheduled {
                Text("Set the days and times in the preset's details.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Create") {
                    manager.addPreset(duration: duration)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 260)
    }
}

struct LibraryView: View {
    @EnvironmentObject var manager: WakeStateManager
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $manager.selectedWakeState) {
                ForEach(manager.wakeStates) { s in
                    SidebarRow(state: s)
                        .tag(s)
                }
            }
            .frame(minWidth: 150)
            .navigationTitle("Kona Library")
            .toolbar {
                Button(action: {
                    manager.showingNewPresetPrompt = true
                }) {
                    Image(systemName: "plus")
                }
            }
        } detail: {
            if let selectedState = manager.selectedWakeState {
                EditWakeStateView(state: selectedState)
                    .id(selectedState.id)
            } else {
                Text("Select a Preset in the sidebar to edit or create a new one.")
            }
        }
        .sheet(isPresented: $manager.showingNewPresetPrompt) {
            NewPresetSheet()
                .environmentObject(manager)
        }
        .onChange(of: manager.sidebarVisible) { newValue in
            columnVisibility = newValue ? .all : .detailOnly
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 450, idealWidth: 550, minHeight: 300, idealHeight: 400)
    }
}
