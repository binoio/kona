//
//  WakeStateManager.swift
//  Kona
//
//  Created by GitHub Copilot on 2025-12-26.
//

import Foundation
import Combine
import AppKit

class WakeStateManager: ObservableObject {
    static let shared = WakeStateManager()
    
    @Published var wakeStates: [WakeState] = []
    @Published var currentEnabled: WakeState?
    @Published var selectedWakeState: WakeState?
    @Published var sidebarVisible: Bool = true
    
    private var activity: NSObjectProtocol?
    private var timer: Timer?
    private let saveKey = "wakeStates"
    
    init() {
        loadWakeStates()
        createDefaultIndefinite()
        startSchedulingTimer()
    }
    
    func loadWakeStates() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let states = try? JSONDecoder().decode([WakeState].self, from: data) {
            wakeStates = states
        }
    }
    
    func saveWakeStates() {
        if let data = try? JSONEncoder().encode(wakeStates) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
        // Trigger UI update by reassigning the array (notifies observers of changes within items)
        objectWillChange.send()
    }
    
    func createDefaultIndefinite() {
        if !wakeStates.contains(where: { $0.name == "Indefinite" }) {
            let indefinite = WakeState(
                name: "Indefinite",
                isEnabled: false,
                schedule: nil,
                options: WakeState.StateOptions(allowScreenDim: false, allowSystemLock: false)
            )
            wakeStates.append(indefinite)
            saveWakeStates()
        }
    }
    
    func enableWakeState(_ state: WakeState) {
        // Disable all others
        for i in wakeStates.indices {
            wakeStates[i].isEnabled = false
            wakeStates[i].enabledAt = nil
        }
        if let index = wakeStates.firstIndex(where: { $0.id == state.id }) {
            wakeStates[index].isEnabled = true
            wakeStates[index].enabledAt = Date()
            currentEnabled = wakeStates[index]
        }
        saveWakeStates()
        updateSystemSleep()
        // Refresh the menu and icon so UI reflects current state
        (NSApp.delegate as? AppDelegate)?.setupMenuBar()
        (NSApp.delegate as? AppDelegate)?.updateMenuBarIcon()
    }
    
    func disableWakeState(_ state: WakeState) {
        if let index = wakeStates.firstIndex(where: { $0.id == state.id }) {
            wakeStates[index].isEnabled = false
            wakeStates[index].enabledAt = nil
            currentEnabled = nil
        }
        saveWakeStates()
        updateSystemSleep()
        // Refresh the menu and icon so UI reflects current state
        (NSApp.delegate as? AppDelegate)?.setupMenuBar()
        (NSApp.delegate as? AppDelegate)?.updateMenuBarIcon()
    }
    
    func addWakeState(_ state: WakeState) {
        wakeStates.append(state)
        saveWakeStates()
        // Make the newly added state the selected one in the UI
        selectedWakeState = state
        // Refresh menubar so any UI reflects changes
        (NSApp.delegate as? AppDelegate)?.setupMenuBar()
    }
    
    func deleteWakeState(_ state: WakeState) {
        wakeStates.removeAll { $0.id == state.id }
        if currentEnabled?.id == state.id {
            currentEnabled = nil
            updateSystemSleep()
        }
        saveWakeStates()
    }
    
    func duplicateWakeState(_ state: WakeState) {
        // Determine the root/base name (strip existing " (Copy N)" suffix if present)
        let copySuffixRegex = try? NSRegularExpression(pattern: "\\s\\(Copy(?: \\d+)?\\)$", options: [])
        var base = state.name
        if let regex = copySuffixRegex {
            let range = NSRange(base.startIndex..<base.endIndex, in: base)
            if let match = regex.firstMatch(in: base, options: [], range: range) {
                if let r = Range(match.range, in: base) {
                    base = String(base[..<r.lowerBound])
                }
            }
        }

        // Generate a unique copy name like "Name (Copy 1)", "Name (Copy 2)" ...
        let pattern = "^" + NSRegularExpression.escapedPattern(for: base) + " \\(Copy(?: (\\d+))?\\)$"
        var maxIndex = 0
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            for s in wakeStates {
                let name = s.name
                let range = NSRange(name.startIndex..<name.endIndex, in: name)
                if let match = regex.firstMatch(in: name, options: [], range: range) {
                    if match.numberOfRanges >= 2 {
                        let groupRange = match.range(at: 1)
                        if groupRange.location != NSNotFound, let r = Range(groupRange, in: name) {
                            let numStr = String(name[r])
                            if let num = Int(numStr) {
                                maxIndex = max(maxIndex, num)
                            } else {
                                maxIndex = max(maxIndex, 1)
                            }
                        } else {
                            maxIndex = max(maxIndex, 1)
                        }
                    }
                }
            }
        }
        let newIndex = maxIndex + 1
        let newName = "\(base) (Copy \(newIndex))"
        // Create a new WakeState instance rather than mutating the existing one
        let newState = WakeState(name: newName, isEnabled: false, schedule: state.schedule, options: state.options, duration: state.duration)
        addWakeState(newState)
        // Select the new duplicated state
        selectedWakeState = newState
    }
    
    private func startSchedulingTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkSchedules()
            self?.checkDurations()
        }
    }
    
    private func checkDurations() {
        let now = Date()
        for state in wakeStates {
            if state.isEnabled,
               let enabledAt = state.enabledAt,
               let duration = state.duration.timeInterval {
                if now.timeIntervalSince(enabledAt) >= duration {
                    disableWakeState(state)
                }
            }
        }
    }
    
    private func checkSchedules() {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let time = calendar.dateComponents([.hour, .minute], from: now)
        
        for state in wakeStates {
            if let schedule = state.schedule {
                if schedule.days.contains(Weekday(rawValue: weekdayString(from: weekday))!) {
                    let startComponents = calendar.dateComponents([.hour, .minute], from: schedule.startTime)
                    let endComponents = calendar.dateComponents([.hour, .minute], from: schedule.endTime)
                    
                    let startHour = startComponents.hour ?? 0
                    let startMinute = startComponents.minute ?? 0
                    let endHour = endComponents.hour ?? 0
                    let endMinute = endComponents.minute ?? 0
                    let currentHour = time.hour ?? 0
                    let currentMinute = time.minute ?? 0
                    
                    let startTotal = startHour * 60 + startMinute
                    let endTotal = endHour * 60 + endMinute
                    let currentTotal = currentHour * 60 + currentMinute
                    
                    if currentTotal >= startTotal && currentTotal <= endTotal {
                        if !state.isEnabled {
                            enableWakeState(state)
                        }
                    } else {
                        if state.isEnabled {
                            disableWakeState(state)
                        }
                    }
                }
            }
        }
    }
    
    private func weekdayString(from weekday: Int) -> String {
        let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        return weekdays[weekday - 1]
    }
    
    private func updateSystemSleep() {
        // End previous activity
        if let activity = activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
        
        if let enabled = currentEnabled {
            // Prevent sleep based on options
            var options: ProcessInfo.ActivityOptions = [.idleSystemSleepDisabled]
            if !enabled.options.allowScreenDim {
                options.insert(.idleDisplaySleepDisabled)
            }
            // For system lock, more complex, but for now, assume idleDisplaySleepDisabled prevents lock too
            activity = ProcessInfo.processInfo.beginActivity(options: options, reason: "Kona Wake State: \(enabled.name)")
            print("Preventing sleep for \(enabled.name)")
        } else {
            // Allow sleep
            print("Allowing sleep")
        }
    }
}