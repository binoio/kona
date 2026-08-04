//
//  WakeStateManagerTests.swift
//  KonaTests
//
//  Created by GitHub Copilot on 2025-12-26.
//

import XCTest
@testable import KonaCore

final class WakeStateManagerTests: XCTestCase {
    var manager: WakeStateManager!
    
    override func setUp() {
        super.setUp()
        manager = WakeStateManager()
        manager.wakeStates = [] // Reset
    }
    
    func testEnableWakeState() {
        let state1 = WakeState(name: "Test1", options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true), duration: .indefinite)
        let state2 = WakeState(name: "Test2", options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true), duration: .indefinite)
        manager.addWakeState(state1)
        manager.addWakeState(state2)
        
        manager.enableWakeState(state1)
        XCTAssertTrue(manager.wakeStates[0].isEnabled)
        XCTAssertFalse(manager.wakeStates[1].isEnabled)
        XCTAssertEqual(manager.currentEnabled?.id, state1.id)
    }
    
    func testOnlyOneEnabled() {
        let state1 = WakeState(name: "Test1", options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true), duration: .indefinite)
        let state2 = WakeState(name: "Test2", options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true), duration: .indefinite)
        manager.addWakeState(state1)
        manager.addWakeState(state2)
        
        manager.enableWakeState(state1)
        manager.enableWakeState(state2)
        XCTAssertFalse(manager.wakeStates[0].isEnabled)
        XCTAssertTrue(manager.wakeStates[1].isEnabled)
    }
    
    func testDuplicateWakeState() {
        let state = WakeState(name: "1 Hour", options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true), duration: .oneHour)
        manager.addWakeState(state)

        manager.duplicateWakeState(state)
        XCTAssertEqual(manager.wakeStates.count, 2)
        XCTAssertEqual(manager.wakeStates[1].name, "1 Hour (1)")
        XCTAssertEqual(manager.wakeStates[1].duration, .oneHour)
    }

    func testDuplicateWakeStateMultiple() {
        let state = WakeState(name: "Foo", options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true), duration: .indefinite)
        manager.addWakeState(state)
        manager.duplicateWakeState(state)
        manager.duplicateWakeState(state)
        XCTAssertEqual(manager.wakeStates.count, 3)
        XCTAssertEqual(manager.wakeStates[1].name, "Foo (1)")
        XCTAssertEqual(manager.wakeStates[2].name, "Foo (2)")
        XCTAssertNotEqual(manager.wakeStates[1].id, manager.wakeStates[2].id)
    }

    func testDuplicateOfDuplicateDoesNotStackSuffixes() {
        let state = WakeState(name: "Foo", options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true), duration: .indefinite)
        manager.addWakeState(state)
        manager.duplicateWakeState(state)
        manager.duplicateWakeState(manager.wakeStates[1])
        XCTAssertEqual(manager.wakeStates[2].name, "Foo (2)")
    }

    func testAddPresetIsNamedForDuration() {
        let preset = manager.addPreset(duration: .thirtyMinutes)
        XCTAssertEqual(preset.name, "30 Minutes")
        XCTAssertEqual(preset.duration, .thirtyMinutes)
        XCTAssertNil(preset.schedule)
    }

    func testAddPresetDefaultsToScreenDimAndLockDisabled() {
        let preset = manager.addPreset(duration: .oneHour)
        XCTAssertFalse(preset.options.allowScreenDim, "New presets should not allow screen dim by default")
        XCTAssertFalse(preset.options.allowSystemLock, "New presets should not allow system lock by default")
    }

    func testAddPresetAppendsIndexForDuplicateNames() {
        manager.addPreset(duration: .oneHour)
        let second = manager.addPreset(duration: .oneHour)
        let third = manager.addPreset(duration: .oneHour)
        XCTAssertEqual(second.name, "1 Hour (1)")
        XCTAssertEqual(third.name, "1 Hour (2)")
    }

    func testAddScheduledPresetHasSchedule() {
        let preset = manager.addPreset(duration: .scheduled)
        XCTAssertEqual(preset.name, "Scheduled")
        XCTAssertEqual(preset.duration, .scheduled)
        XCTAssertNotNil(preset.schedule)
        XCTAssertNil(preset.duration.timeInterval, "Scheduled presets have no fixed duration")
    }

    func testAddPresetSelectsNewPreset() {
        let preset = manager.addPreset(duration: .fifteenMinutes)
        XCTAssertEqual(manager.selectedWakeState?.id, preset.id)
    }

    func testSleepAtEndDefaultsToFalse() {
        let preset = manager.addPreset(duration: .oneHour)
        XCTAssertFalse(preset.options.sleepAtEnd, "Sleep at the end should be disabled by default")
    }

    func testStateOptionsDecodingLegacyDataWithoutSleepAtEnd() throws {
        let legacyJSON = Data("{\"allowScreenDim\": true, \"allowSystemLock\": false}".utf8)
        let options = try JSONDecoder().decode(WakeState.StateOptions.self, from: legacyJSON)
        XCTAssertTrue(options.allowScreenDim)
        XCTAssertFalse(options.allowSystemLock)
        XCTAssertFalse(options.sleepAtEnd, "Presets saved before the option existed should default to no sleep")
    }

    func testExpiredTimerTriggersSleepWhenOptionEnabled() {
        var sleepTriggered = false
        manager.triggerSystemSleep = { sleepTriggered = true }

        let state = WakeState(
            name: "15 Minutes",
            options: WakeState.StateOptions(allowScreenDim: false, allowSystemLock: false, sleepAtEnd: true),
            duration: .fifteenMinutes
        )
        manager.addWakeState(state)
        manager.enableWakeState(state)
        state.enabledAt = Date().addingTimeInterval(-16 * 60)

        manager.checkDurations()
        XCTAssertFalse(state.isEnabled, "Preset should be disabled once its timer expires")
        XCTAssertTrue(sleepTriggered, "Sleep at the end should trigger a system sleep when the timer expires")
    }

    func testExpiredTimerDoesNotSleepWhenOptionDisabled() {
        var sleepTriggered = false
        manager.triggerSystemSleep = { sleepTriggered = true }

        let state = WakeState(
            name: "15 Minutes",
            options: WakeState.StateOptions(allowScreenDim: false, allowSystemLock: false, sleepAtEnd: false),
            duration: .fifteenMinutes
        )
        manager.addWakeState(state)
        manager.enableWakeState(state)
        state.enabledAt = Date().addingTimeInterval(-16 * 60)

        manager.checkDurations()
        XCTAssertFalse(state.isEnabled)
        XCTAssertFalse(sleepTriggered, "System sleep must not trigger when the option is disabled")
    }

    func testStaleEnabledFlagIsResetOnRelaunch() {
        let state = WakeState(name: "Stale", options: WakeState.StateOptions(allowScreenDim: false, allowSystemLock: false), duration: .indefinite)
        manager.addWakeState(state)
        manager.enableWakeState(state)

        // Simulate a relaunch: a fresh manager loads the persisted data
        let relaunched = WakeStateManager()
        defer { UserDefaults.standard.removeObject(forKey: "wakeStates") }

        guard let loaded = relaunched.wakeStates.first(where: { $0.id == state.id }) else {
            XCTFail("Persisted preset should survive relaunch")
            return
        }
        XCTAssertFalse(loaded.isEnabled,
                       "A relaunched app holds no sleep assertion; the persisted enabled flag must not show a checked menu item over an inactive icon")
        XCTAssertNil(loaded.enabledAt)
        XCTAssertNil(relaunched.currentEnabled)
    }

    func testInWindowScheduledPresetActivatesOnRelaunch() {
        // Build a schedule containing this moment: today's weekday, a window
        // clamped to today so runs near midnight stay inside it
        let calendar = Calendar.current
        let now = Date()
        let weekdays: [Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let today = weekdays[calendar.component(.weekday, from: now) - 1]
        let nowMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let startMinutes = max(0, nowMinutes - 60)
        let endMinutes = min(23 * 60 + 59, nowMinutes + 60)
        let schedule = WakeState.Schedule(
            days: [today],
            startTime: calendar.date(bySettingHour: startMinutes / 60, minute: startMinutes % 60, second: 0, of: now)!,
            endTime: calendar.date(bySettingHour: endMinutes / 60, minute: endMinutes % 60, second: 0, of: now)!
        )
        let state = WakeState(name: "Evenings", schedule: schedule,
                              options: WakeState.StateOptions(allowScreenDim: false, allowSystemLock: false),
                              duration: .scheduled)
        manager.addWakeState(state)

        // Simulate a relaunch inside the scheduled window
        let relaunched = WakeStateManager()
        defer { UserDefaults.standard.removeObject(forKey: "wakeStates") }

        guard let loaded = relaunched.wakeStates.first(where: { $0.id == state.id }) else {
            XCTFail("Persisted preset should survive relaunch")
            return
        }
        XCTAssertTrue(loaded.isEnabled,
                      "Launching inside a scheduled window must activate the preset immediately, not after the first timer tick")
        XCTAssertEqual(relaunched.currentEnabled?.id, state.id)
    }

    func testRemainingTimeForScheduledPresetCountsDownToWindowEnd() {
        let calendar = Calendar.current
        let now = Date()
        let nowMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let endMinutes = min(23 * 60 + 59, nowMinutes + 30)
        let schedule = WakeState.Schedule(
            days: Weekday.allCases,
            startTime: now.addingTimeInterval(-600),
            endTime: calendar.date(bySettingHour: endMinutes / 60, minute: endMinutes % 60, second: 0, of: now)!
        )
        let state = WakeState(name: "Evenings", schedule: schedule,
                              options: WakeState.StateOptions(allowScreenDim: false, allowSystemLock: false),
                              duration: .scheduled)

        guard let remaining = state.remainingTime(at: now) else {
            XCTFail("An active scheduled preset must report time remaining until its window ends")
            return
        }
        // The window stays active through the whole end minute, so it closes at endTime + 60s
        let secondsIntoDay = now.timeIntervalSince(calendar.startOfDay(for: now))
        let expected = Double(endMinutes * 60 + 60) - secondsIntoDay
        XCTAssertEqual(remaining, expected, accuracy: 2,
                       "Scheduled remaining time should count down to the end of today's window")
    }

    func testRemainingTimeIsNilForIndefinite() {
        let state = WakeState(name: "Indefinite", options: WakeState.StateOptions(allowScreenDim: false, allowSystemLock: false), duration: .indefinite)
        XCTAssertNil(state.remainingTime())
    }

    func testRemainingTimeForTimedPresetUsesEnabledAt() {
        let state = WakeState(name: "15 Minutes", options: WakeState.StateOptions(allowScreenDim: false, allowSystemLock: false), duration: .fifteenMinutes)
        state.enabledAt = Date().addingTimeInterval(-5 * 60)
        guard let remaining = state.remainingTime() else {
            XCTFail("Timed presets must report time remaining")
            return
        }
        XCTAssertEqual(remaining, 10 * 60, accuracy: 2)
    }

    func testManualDisableDoesNotTriggerSleep() {
        var sleepTriggered = false
        manager.triggerSystemSleep = { sleepTriggered = true }

        let state = WakeState(
            name: "15 Minutes",
            options: WakeState.StateOptions(allowScreenDim: false, allowSystemLock: false, sleepAtEnd: true),
            duration: .fifteenMinutes
        )
        manager.addWakeState(state)
        manager.enableWakeState(state)
        manager.disableWakeState(state)

        XCTAssertFalse(sleepTriggered, "Manually disabling a preset must not sleep the system; only timer expiry does")
    }
}