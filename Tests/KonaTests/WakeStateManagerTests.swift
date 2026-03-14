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
        let state = WakeState(name: "Original", options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true), duration: .oneHour)
        manager.addWakeState(state)
        
        manager.duplicateWakeState(state)
        XCTAssertEqual(manager.wakeStates.count, 2)
        XCTAssertEqual(manager.wakeStates[1].name, "Original (Copy 1)")
        XCTAssertEqual(manager.wakeStates[1].duration, .oneHour)
    }

    func testDuplicateWakeStateMultiple() {
        let state = WakeState(name: "Foo", options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true), duration: .indefinite)
        manager.addWakeState(state)
        manager.duplicateWakeState(state)
        manager.duplicateWakeState(state)
        XCTAssertEqual(manager.wakeStates.count, 3)
        XCTAssertEqual(manager.wakeStates[1].name, "Foo (Copy 1)")
        XCTAssertEqual(manager.wakeStates[2].name, "Foo (Copy 2)")
        XCTAssertNotEqual(manager.wakeStates[1].id, manager.wakeStates[2].id)
    }
}