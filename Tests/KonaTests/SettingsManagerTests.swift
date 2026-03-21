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
        settings.hideDockIcon = false
        settings.showMenuBarItem = true
        settings.showRemainingTimeInMenuBar = false
    }
    
    func testShowRemainingTimeToggle() {
        XCTAssertFalse(settings.showRemainingTimeInMenuBar)
        settings.showRemainingTimeInMenuBar = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "showRemainingTimeInMenuBar"))
        
        settings.showRemainingTimeInMenuBar = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "showRemainingTimeInMenuBar"))
    }

    func testHideDockIconPersistsAndRequiresMenuBarItem() {
        settings.showMenuBarItem = false
        settings.hideDockIcon = true

        XCTAssertTrue(settings.hideDockIcon)
        XCTAssertTrue(settings.showMenuBarItem)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hideDockIcon"))
    }

    func testDisablingMenuBarItemRestoresDockIcon() {
        settings.hideDockIcon = true

        settings.showMenuBarItem = false

        XCTAssertFalse(settings.hideDockIcon)
        XCTAssertFalse(settings.showMenuBarItem)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "hideDockIcon"))
    }
}
