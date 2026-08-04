//
//  WakeStateManager.swift
//  Kona
//
//  Created by GitHub Copilot on 2025-12-26.
//

import Foundation
import Combine
import AppKit

public class WakeStateManager: ObservableObject {
    public static let shared = WakeStateManager()
    
    @Published var wakeStates: [WakeState] = []
    @Published var currentEnabled: WakeState?
    @Published var selectedWakeState: WakeState?
    @Published var sidebarVisible: Bool = true
    @Published var showingNewPresetPrompt: Bool = false
    @Published var libraryWindowVisible: Bool = false
    
    private var activity: NSObjectProtocol?
    private var timer: Timer?
    private let saveKey = "wakeStates"

    // Injectable so tests can observe the sleep trigger without sleeping the
    // machine, and so the sandboxed App Store shell can swap in an Apple
    // Event to System Events (pmset is denied inside the sandbox)
    public var triggerSystemSleep: () -> Void = {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["sleepnow"]
        do {
            try task.run()
        } catch {
            print("Failed to trigger system sleep: \(error)")
        }
    }
    
    init() {
        loadWakeStates()
        createDefaultIndefinite()
        startSchedulingTimer()
    }
    
    func loadWakeStates() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let states = try? JSONDecoder().decode([WakeState].self, from: data) {
            // Presets saved before the Scheduled duration existed carried a schedule
            // alongside a fixed duration; the schedule now implies the duration.
            for state in states where state.schedule != nil {
                state.duration = .scheduled
            }
            // isEnabled is persisted, but a fresh launch holds no sleep
            // assertion and no currentEnabled — a stale flag shows a checked
            // menu item over an inactive icon while nothing keeps the Mac
            // awake. Start from a clean slate; checkSchedules() re-activates
            // in-window scheduled presets immediately.
            for state in states where state.isEnabled {
                state.isEnabled = false
                state.enabledAt = nil
            }
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
        (NSApp.delegate as? KonaAppDelegate)?.setupMenuBar()
        (NSApp.delegate as? KonaAppDelegate)?.updateMenuBarIcon()
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
        (NSApp.delegate as? KonaAppDelegate)?.setupMenuBar()
        (NSApp.delegate as? KonaAppDelegate)?.updateMenuBarIcon()
    }
    
    func addWakeState(_ state: WakeState) {
        wakeStates.append(state)
        saveWakeStates()
        // Make the newly added state the selected one in the UI
        selectedWakeState = state
        // Refresh menubar so any UI reflects changes
        (NSApp.delegate as? KonaAppDelegate)?.setupMenuBar()
    }
    
    func deleteWakeState(_ state: WakeState) {
        wakeStates.removeAll { $0.id == state.id }
        if selectedWakeState?.id == state.id {
            selectedWakeState = nil
        }
        if currentEnabled?.id == state.id {
            currentEnabled = nil
            updateSystemSleep()
        }
        saveWakeStates()
    }
    
    /// Creates a preset for the given duration, named after the duration
    /// with " (1)", " (2)" appended when the name is already taken.
    @discardableResult
    func addPreset(duration: WakeDuration) -> WakeState {
        let schedule: WakeState.Schedule? = duration == .scheduled
            ? WakeState.Schedule(days: [], startTime: Date(), endTime: Date().addingTimeInterval(3600))
            : nil
        let newState = WakeState(
            name: uniquePresetName(for: duration.rawValue),
            schedule: schedule,
            options: WakeState.StateOptions(allowScreenDim: false, allowSystemLock: false),
            duration: duration
        )
        addWakeState(newState)
        return newState
    }

    func uniquePresetName(for base: String) -> String {
        let existing = Set(wakeStates.map { $0.name })
        if !existing.contains(base) { return base }
        var index = 1
        while existing.contains("\(base) (\(index))") { index += 1 }
        return "\(base) (\(index))"
    }

    func duplicateWakeState(_ state: WakeState) {
        // Strip an existing " (N)" suffix so copies of copies don't stack suffixes
        var base = state.name
        if let range = base.range(of: #" \(\d+\)$"#, options: .regularExpression) {
            base.removeSubrange(range)
        }
        let newState = WakeState(name: uniquePresetName(for: base), isEnabled: false, schedule: state.schedule, options: state.options, duration: state.duration)
        addWakeState(newState)
    }
    
    private func startSchedulingTimer() {
        // Reconcile immediately so a launch inside a scheduled window
        // activates the preset now, not up to a minute later
        checkSchedules()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkSchedules()
            self?.checkDurations()
        }
    }
    
    func checkDurations() {
        let now = Date()
        for state in wakeStates {
            if state.isEnabled,
               let enabledAt = state.enabledAt,
               let duration = state.duration.timeInterval {
                if now.timeIntervalSince(enabledAt) >= duration {
                    disableWakeState(state)
                    if state.options.sleepAtEnd {
                        triggerSystemSleep()
                    }
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