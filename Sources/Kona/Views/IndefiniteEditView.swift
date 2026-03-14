//
//  IndefiniteEditView.swift
//  Kona
//
//  Created by GitHub Copilot on 2025-12-26.
//

import SwiftUI

struct IndefiniteEditView: View {
    @ObservedObject var state: WakeState
    @EnvironmentObject var manager: WakeStateManager
    
    @State private var allowScreenDim: Bool
    @State private var allowSystemLock: Bool
    @State private var duration: WakeDuration
    @State private var hasSchedule: Bool = false
    @State private var selectedDays: Set<Weekday> = []
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600)
    
    init(state: WakeState) {
        self.state = state
        _allowScreenDim = State(initialValue: state.options.allowScreenDim)
        _allowSystemLock = State(initialValue: state.options.allowSystemLock)
        _duration = State(initialValue: state.duration)
        if let schedule = state.schedule {
            _hasSchedule = State(initialValue: true)
            _selectedDays = State(initialValue: Set(schedule.days))
            _startTime = State(initialValue: schedule.startTime)
            _endTime = State(initialValue: schedule.endTime)
        }
    }
    
    var body: some View {
        Form {
            Picker("Duration", selection: $duration) {
                ForEach(WakeDuration.allCases, id: \.self) { d in
                    Text(d.rawValue).tag(d)
                }
            }
            .onChange(of: duration) { _ in save() }
            
            Toggle("Allow screen dim", isOn: $allowScreenDim)
                .onChange(of: allowScreenDim) { _ in save() }
            Toggle("Allow system lock", isOn: $allowSystemLock)
                .onChange(of: allowSystemLock) { _ in save() }
            
            Divider()
                .padding(.vertical, 8)
            
            Toggle("Enable scheduling", isOn: $hasSchedule)
                .onChange(of: hasSchedule) { _ in save() }
            if hasSchedule {
                DayPicker(selections: $selectedDays)
                    .onChange(of: selectedDays) { _ in save() }
                DatePicker("Start time", selection: $startTime, displayedComponents: .hourAndMinute)
                    .onChange(of: startTime) { _ in save() }
                DatePicker("End time", selection: $endTime, displayedComponents: .hourAndMinute)
                    .onChange(of: endTime) { _ in save() }
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle(state.name)
    }
    
    private func save() {
        state.options = WakeState.StateOptions(allowScreenDim: allowScreenDim, allowSystemLock: allowSystemLock)
        state.duration = duration
        if hasSchedule {
            state.schedule = WakeState.Schedule(days: Array(selectedDays), startTime: startTime, endTime: endTime)
        } else {
            state.schedule = nil
        }
        manager.saveWakeStates()
    }
}