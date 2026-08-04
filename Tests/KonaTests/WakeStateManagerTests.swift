//
//  WakeStateManagerTests.swift
//  KonaTests
//
//  Created by GitHub Copilot on 2025-12-26.
//

import XCTest
@testable import Kona

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