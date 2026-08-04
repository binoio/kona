//
//  DefaultsMigratorTests.swift
//  KonaTests
//

import XCTest
@testable import Kona

final class DefaultsMigratorTests: XCTestCase {
    private let sourceSuite = "test.kona.migrator.source"
    private let targetSuite = "test.kona.migrator.target"
    private var source: UserDefaults!
    private var target: UserDefaults!

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: sourceSuite)
        UserDefaults().removePersistentDomain(forName: targetSuite)
        source = UserDefaults(suiteName: sourceSuite)
        target = UserDefaults(suiteName: targetSuite)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: sourceSuite)
        UserDefaults().removePersistentDomain(forName: targetSuite)
        super.tearDown()
    }

    func testMigratesKnownKeysIncludingPresetData() {
        let presetData = Data("fake-wake-states-json".utf8)
        source.set(presetData, forKey: "wakeStates")
        source.set(true, forKey: "hideDockIcon")
        source.set("some-uuid", forKey: "launchWakeStateId")

        DefaultsMigrator.migrateIfNeeded(from: source, to: target)

        XCTAssertEqual(target.data(forKey: "wakeStates"), presetData)
        XCTAssertTrue(target.bool(forKey: "hideDockIcon"))
        XCTAssertEqual(target.string(forKey: "launchWakeStateId"), "some-uuid")
        XCTAssertTrue(target.bool(forKey: DefaultsMigrator.migrationKey))
    }

    func testDoesNotOverwriteExistingTargetValues() {
        source.set(Data("old".utf8), forKey: "wakeStates")
        target.set(Data("new".utf8), forKey: "wakeStates")

        DefaultsMigrator.migrateIfNeeded(from: source, to: target)

        XCTAssertEqual(target.data(forKey: "wakeStates"), Data("new".utf8))
    }

    func testSecondRunIsANoOpEvenIfSourceChanges() {
        source.set(Data("first".utf8), forKey: "wakeStates")
        DefaultsMigrator.migrateIfNeeded(from: source, to: target)

        target.removeObject(forKey: "wakeStates")
        source.set(Data("second".utf8), forKey: "wakeStates")
        DefaultsMigrator.migrateIfNeeded(from: source, to: target)

        XCTAssertNil(target.data(forKey: "wakeStates"), "Migration must not run twice")
    }

    func testNilSourceSetsMarkerWithoutCopying() {
        DefaultsMigrator.migrateIfNeeded(from: nil, to: target)

        XCTAssertTrue(target.bool(forKey: DefaultsMigrator.migrationKey))
        for key in DefaultsMigrator.migratedKeys {
            XCTAssertNil(target.object(forKey: key))
        }
    }

    func testUnknownKeysAreNotCopied() {
        source.set("secret", forKey: "unrelatedKey")

        DefaultsMigrator.migrateIfNeeded(from: source, to: target)

        XCTAssertNil(target.object(forKey: "unrelatedKey"))
    }
}
