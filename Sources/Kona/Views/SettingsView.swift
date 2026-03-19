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
    
    var body: some View {
        Form {
            Toggle("Show menu bar item", isOn: $settings.showMenuBarItem)
            Toggle("Show remaining time in menu bar", isOn: $settings.showRemainingTimeInMenuBar)
            Toggle("Open at login", isOn: $settings.openAtLogin)
            
            Picker("Activate on launch", selection: $settings.launchWakeStateId) {
                Text("None").tag(nil as UUID?)
                ForEach(wakeStateManager.wakeStates) { state in
                    Text(state.name).tag(state.id as UUID?)
                }
            }
        }
        .padding()
        .frame(width: 450, height: 180)
    }
}