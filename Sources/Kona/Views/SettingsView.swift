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
                        ForEach(wakeStateManager.wakeStates) { state in
                            Text(state.name).tag(state.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .formStyle(.grouped)
        }
        .padding(24)
        .frame(width: 520, height: 400)
    }
}
