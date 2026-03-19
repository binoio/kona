//
//  SettingsManagerTests.swift
//  KonaTests
//
//  Created by GitHub Copilot on 2025-12-26.
//

import XCTest
@testable import Kona

final class SettingsManagerTests: XCTestCase {
    var settings: SettingsManager!
    
    override func setUp() {
        super.setUp()
        settings = SettingsManager.shared
        // Reset to default
        settings.showRemainingTimeInMenuBar = false
    }
    
    func testShowRemainingTimeToggle() {
        XCTAssertFalse(settings.showRemainingTimeInMenuBar)
        settings.showRemainingTimeInMenuBar = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "showRemainingTimeInMenuBar"))
        
        settings.showRemainingTimeInMenuBar = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "showRemainingTimeInMenuBar"))
    }
}