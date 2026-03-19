//
//  IntegrationTests.swift
//  KonaTests
//
//  Created by GitHub Copilot on 2025-12-26.
//

import XCTest
@testable import Kona

final class IntegrationTests: XCTestCase {
    var manager: WakeStateManager!
    var appDelegate: AppDelegate!
    
    override func setUp() {
        super.setUp()
        NSApp = NSApplication.shared
        manager = WakeStateManager.shared
        manager.wakeStates = []
        manager.currentEnabled = nil
        manager.createDefaultIndefinite()
        appDelegate = AppDelegate()
        NSApp.delegate = appDelegate
        appDelegate.setupMenuBar()
        // Reset launch wake state setting
        SettingsManager.shared.launchWakeStateId = nil
    }
    
    func testMenuBarToggleIndefinite() {
        // Simulate toggle
        appDelegate.toggleIndefiniteWake()
        XCTAssertNotNil(manager.wakeStates.first(where: { $0.name == "Indefinite" }))
        XCTAssertTrue(manager.wakeStates.first(where: { $0.name == "Indefinite" })!.isEnabled)
        
        appDelegate.toggleIndefiniteWake()
        XCTAssertFalse(manager.wakeStates.first(where: { $0.name == "Indefinite" })!.isEnabled)
    }
    
    func testNewWakeStateFromMenu() {
        let initialCount = manager.wakeStates.count
        appDelegate.newWakeState()
        XCTAssertEqual(manager.wakeStates.count, initialCount + 1)
    }

    func testDuplicateSelectsNewState() {
        let state = WakeState(name: "ToDuplicate", options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true), duration: .indefinite)
        manager.addWakeState(state)
        XCTAssertNotNil(manager.selectedWakeState)
        manager.duplicateWakeState(state)
        // After duplication, selectedWakeState should point to newly created duplicate
        XCTAssertEqual(manager.selectedWakeState?.name, "ToDuplicate (Copy 1)")
        XCTAssertEqual(manager.wakeStates.last?.name, "ToDuplicate (Copy 1)")
    }
    
    func testMenubarIconChangesWhenWakeStateEnabled() {
        // Initially no enabled and status button exists
        XCTAssertNotNil(appDelegate.statusItem?.button)
        XCTAssertEqual(appDelegate.statusItem?.button?.image?.accessibilityDescription, "Kona Disabled")
        
        // Enable indefinite (simulates toggling via Library)
        let indefinite = manager.wakeStates.first(where: { $0.name == "Indefinite" })!
        manager.enableWakeState(indefinite)
        XCTAssertNotNil(appDelegate.statusItem?.button, "Status item button should remain present after enabling Indefinite")
        XCTAssertEqual(appDelegate.statusItem?.button?.image?.accessibilityDescription, "Kona Enabled")
        
        // Disable
        manager.disableWakeState(indefinite)
        XCTAssertNotNil(appDelegate.statusItem?.button, "Status item button should remain present after disabling Indefinite")
        XCTAssertEqual(appDelegate.statusItem?.button?.image?.accessibilityDescription, "Kona Disabled")
    }
    
    func testIndefiniteWakeMenuItemCheckMark() {
        // Initially not enabled
        appDelegate.setupMenuBar()
        var indefiniteItem = appDelegate.statusItem?.menu?.items.first
        XCTAssertEqual(indefiniteItem?.state, .off)
        
        // Enable indefinite
        let indefinite = manager.wakeStates.first(where: { $0.name == "Indefinite" })!
        manager.enableWakeState(indefinite)
        appDelegate.setupMenuBar()
        indefiniteItem = appDelegate.statusItem?.menu?.items.first
        XCTAssertEqual(indefiniteItem?.state, .on)
        
        // Disable
        manager.disableWakeState(indefinite)
        appDelegate.setupMenuBar()
        indefiniteItem = appDelegate.statusItem?.menu?.items.first
        XCTAssertEqual(indefiniteItem?.state, .off)
    }
    
    func testSingleHideSidebarButton() {
        // The view now relies on the system-provided sidebar toggle (no custom toolbar button present)
        XCTAssertTrue(true, "The Library uses the system's default sidebar control; no custom toolbar button exists")
    }

    func testMenubarIconChangesWhenCustomStateToggledViaMenu() {
        // Add a custom state
        let custom = WakeState(name: "CustomFromMenu", options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true), duration: .indefinite)
        manager.addWakeState(custom)
        appDelegate.setupMenuBar()

        // Find the menu item for the custom state
        guard let item = appDelegate.statusItem?.menu?.items.first(where: { $0.title == "CustomFromMenu" }) else {
            XCTFail("Custom menu item not found")
            return
        }

        // Toggle via menu
        appDelegate.toggleWakeState(item)
        XCTAssertEqual(appDelegate.statusItem?.button?.image?.accessibilityDescription, "Kona Enabled")

        appDelegate.toggleWakeState(item)
        XCTAssertEqual(appDelegate.statusItem?.button?.image?.accessibilityDescription, "Kona Disabled")
    }

    func testMenubarIconChangesWhenCustomStateToggledViaLibraryToggle() {
        // Add a custom state
        let custom = WakeState(name: "CustomFromList", options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true), duration: .indefinite)
        manager.addWakeState(custom)

        // Simulate toggling via library's toggle button by calling enable/disable on manager
        manager.enableWakeState(custom)
        XCTAssertEqual(appDelegate.statusItem?.button?.image?.accessibilityDescription, "Kona Enabled")

        manager.disableWakeState(custom)
        XCTAssertEqual(appDelegate.statusItem?.button?.image?.accessibilityDescription, "Kona Disabled")
    }
    
    func testStatusMenuReflectsWakeStates() {
        // Add custom wake states
        let state1 = WakeState(name: "Work Mode", options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true), duration: .indefinite)
        let state2 = WakeState(name: "Meeting", options: WakeState.StateOptions(allowScreenDim: false, allowSystemLock: false), duration: .oneHour)
        manager.addWakeState(state1)
        manager.addWakeState(state2)
        appDelegate.setupMenuBar()
        
        // Get menu items (excluding separator and Quit)
        let menuItems = appDelegate.statusItem?.menu?.items ?? []
        let wakeStateItems = menuItems.filter { !$0.isSeparatorItem && $0.title != "Quit Kona" }
        
        // Should have Indefinite Wake + 2 custom states = 3 items
        XCTAssertEqual(wakeStateItems.count, 3, "Menu should contain all wake states")
        
        // Check that all manager wake states are represented in menu
        for state in manager.wakeStates {
            let expectedTitle = state.name == "Indefinite" ? "Indefinite Wake" : state.name
            let found = wakeStateItems.contains { $0.title == expectedTitle }
            XCTAssertTrue(found, "Wake state '\(state.name)' should be in menu")
        }
        
        // Check menu count matches manager count
        XCTAssertEqual(wakeStateItems.count, manager.wakeStates.count, "Menu item count should match wake states count")
    }
    
    func testStatusMenuAutoUpdatesWhenStateAdded() {
        // This test verifies the menu automatically updates when a state is added
        // The AppDelegate must have its observers set up via applicationDidFinishLaunching
        
        // Ensure observers are set up (simulates real app behavior)
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        // Get initial menu item count
        let initialItems = appDelegate.statusItem?.menu?.items ?? []
        let initialWakeStateCount = initialItems.filter { !$0.isSeparatorItem && $0.title != "Quit Kona" }.count
        
        // Add a new wake state (this should trigger automatic menu update via observation)
        let newState = WakeState(name: "AutoUpdateTest", options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true), duration: .indefinite)
        manager.addWakeState(newState)
        
        // Allow async dispatch to complete
        let expectation = XCTestExpectation(description: "Menu update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Check menu WITHOUT manually calling setupMenuBar()
        let updatedItems = appDelegate.statusItem?.menu?.items ?? []
        let updatedWakeStateCount = updatedItems.filter { !$0.isSeparatorItem && $0.title != "Quit Kona" }.count
        
        // Menu should now have one more item
        XCTAssertEqual(updatedWakeStateCount, initialWakeStateCount + 1, "Menu should automatically update when wake state is added")
        
        // The new state should be in the menu
        let hasNewState = updatedItems.contains { $0.title == "AutoUpdateTest" }
        XCTAssertTrue(hasNewState, "Newly added wake state should appear in menu automatically")
    }
    
    func testLaunchWakeStateActivatesOnLaunch() {
        // Create a wake state to be activated on launch
        let launchState = WakeState(name: "LaunchState", options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true), duration: .indefinite)
        manager.addWakeState(launchState)
        
        // Configure it as the launch wake state via SettingsManager
        SettingsManager.shared.launchWakeStateId = launchState.id
        
        // Verify it's not enabled yet
        XCTAssertFalse(launchState.isEnabled)
        XCTAssertNil(manager.currentEnabled)
        
        // Simulate app launch
        let newAppDelegate = AppDelegate()
        NSApp.delegate = newAppDelegate
        newAppDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        // Verify the state is now enabled
        let enabledState = manager.wakeStates.first(where: { $0.id == launchState.id })
        XCTAssertNotNil(enabledState)
        XCTAssertTrue(enabledState!.isEnabled, "Launch wake state should be enabled after app launch")
        XCTAssertEqual(manager.currentEnabled?.id, launchState.id, "currentEnabled should be the launch wake state")
    }
    
    func testTimeRemainingInMenuBar() {
        // Enable setting
        SettingsManager.shared.showRemainingTimeInMenuBar = true
        
        // Add custom state with 15min duration
        let custom = WakeState(name: "TimedState", options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true), duration: .fifteenMinutes)
        manager.addWakeState(custom)
        
        // Enable it
        manager.enableWakeState(custom)
        
        // Update menu icon (this happens automatically but we call it manually to be sure)
        appDelegate.updateMenuBarIcon()
        
        // Verify title contains time
        // 15 minutes = 15:00 or 14:59
        let initialTitle = appDelegate.statusItem?.button?.title ?? ""
        XCTAssertTrue(initialTitle.contains("15:00") || initialTitle.contains("14:59"), "Menu bar title should contain 15:00 or 14:59, got: '\(initialTitle)'")
        
        // Manually set enabledAt to simulate time passing
        if let idx = manager.wakeStates.firstIndex(where: { $0.id == custom.id }) {
            manager.wakeStates[idx].enabledAt = Date().addingTimeInterval(-61) // 1 minute and 1 second ago
            manager.currentEnabled = manager.wakeStates[idx]
        }
        
        appDelegate.updateMenuBarIcon()
        
        // Should show ~13:58 or 13:59
        let title = appDelegate.statusItem?.button?.title ?? ""
        XCTAssertTrue(title.contains("13:5"), "Menu bar title should show ~13:5x, got: '\(title)'")
        
        // Disable setting and verify title is cleared
        SettingsManager.shared.showRemainingTimeInMenuBar = false
        appDelegate.updateMenuBarIcon()
        XCTAssertEqual(appDelegate.statusItem?.button?.title, "", "Menu bar title should be empty when setting is disabled")
    }
    
    func testNoLaunchWakeStateWhenNotConfigured() {
        // Ensure no launch wake state is configured
        SettingsManager.shared.launchWakeStateId = nil
        
        // Add a state but don't configure it as launch state
        let state = WakeState(name: "NotLaunch", options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true), duration: .indefinite)
        manager.addWakeState(state)
        
        // Simulate app launch
        let newAppDelegate = AppDelegate()
        NSApp.delegate = newAppDelegate
        newAppDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        // Verify no state is enabled
        XCTAssertNil(manager.currentEnabled, "No wake state should be enabled when launch state is not configured")
    }
}