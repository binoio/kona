//
//  SettingsView.swift
//  Kona
//
//  Created by GitHub Copilot on 2025-12-26.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var wakeStateManager = WakeStateManager.shared
    // Optional so tests and previews can construct the view without Sparkle
    var updaterViewModel: UpdaterViewModel?

    private var showDockIconBinding: Binding<Bool> {
        Binding(
            get: { !settings.hideDockIcon },
            set: { settings.hideDockIcon = !$0 }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Form {
                Section("Appearance") {
                    Toggle("Show menu bar item", isOn: $settings.showMenuBarItem)

                    Toggle("Show remaining time in menu bar", isOn: $settings.showRemainingTimeInMenuBar)
                        .disabled(!settings.showMenuBarItem)

                    Toggle("Show Dock Icon", isOn: showDockIconBinding)

                    if !showDockIconBinding.wrappedValue {
                        Text("Kona will remain available from the menu bar extra while the Dock icon is hidden.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Startup") {
                    Toggle("Open at login", isOn: $settings.openAtLogin)

                    Picker("Activate on launch", selection: $settings.launchWakeStateId) {
                        Text("None").tag(nil as UUID?)
                        // Scheduled presets activate on their schedule only
                        ForEach(wakeStateManager.wakeStates.filter { $0.duration != .scheduled }) { state in
                            Text(state.name).tag(state.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if let updaterViewModel = updaterViewModel {
                    UpdatesSectionView(viewModel: updaterViewModel)
                }
            }
            .formStyle(.grouped)
        }
        .padding(24)
        .frame(width: 520, height: updaterViewModel == nil ? 400 : 500)
    }
}

struct UpdatesSectionView: View {
    @ObservedObject var viewModel: UpdaterViewModel

    var body: some View {
        Section("Updates") {
            Toggle("Automatically check for updates", isOn: Binding(
                get: { viewModel.automaticallyChecksForUpdates },
                set: { viewModel.automaticallyChecksForUpdates = $0 }
            ))
            Toggle("Automatically download updates", isOn: Binding(
                get: { viewModel.automaticallyDownloadsUpdates },
                set: { viewModel.automaticallyDownloadsUpdates = $0 }
            ))
            .disabled(!viewModel.automaticallyChecksForUpdates)

            if let lastCheck = viewModel.lastUpdateCheckDate {
                Text("Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
