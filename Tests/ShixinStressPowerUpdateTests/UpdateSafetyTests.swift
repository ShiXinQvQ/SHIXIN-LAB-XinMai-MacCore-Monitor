// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import ShixinStressPower

final class UpdateSafetyTests: XCTestCase {
    func testUpdateCannotStartUntilEveryActivityFinishes() async {
        await MainActor.run {
            let gate = UpdateActivityGate()
            let network = gate.beginActivity()!
            let export = gate.beginActivity()!
            XCTAssertFalse(gate.beginUpdate())
            gate.endActivity(network)
            XCTAssertFalse(gate.beginUpdate())
            gate.endActivity(network) // Duplicate cleanup must not release somebody else's lease.
            XCTAssertEqual(gate.activityCount, 1)
            gate.endActivity(export)
            XCTAssertTrue(gate.beginUpdate())
            XCTAssertNil(gate.beginActivity())
            gate.endUpdate()
            XCTAssertNotNil(gate.beginActivity())
        }
    }

    func testCancelledTaskHoldsLeaseWhileCleaningUp() async {
        let gate = await UpdateActivityGate()
        let task = Task { @MainActor in
            let lease = gate.beginActivity()!
            defer { gate.endActivity(lease) }
            while !Task.isCancelled { await Task.yield() }
            XCTAssertFalse(gate.beginUpdate())
            // Cancellation has been requested, but task cleanup still owns the activity.
            await Task.yield()
            XCTAssertFalse(gate.beginUpdate())
        }
        while await gate.activityCount == 0 { await Task.yield() }
        task.cancel()
        await task.value
        await MainActor.run { XCTAssertTrue(gate.beginUpdate()) }
    }

    func testMissingAndInsecureReleaseConfigurationCannotStartUpdater() async {
        await MainActor.run {
            let good: [String: Any] = [
                "CFBundleShortVersionString": "0.3.1-beta", "CFBundleVersion": "301",
                "SUPublicEDKey": Data(repeating: 1, count: 32).base64EncodedString(),
                "SUFeedURL": "https://example.com/updates/appcast.xml"
            ]
            XCTAssertTrue(AppUpdateService.hasUpdateConfiguration(good))
            for key in good.keys {
                var missing = good
                missing.removeValue(forKey: key)
                XCTAssertFalse(AppUpdateService.hasUpdateConfiguration(missing), key)
            }
            for feed in ["http://example.com/appcast.xml", "file:///tmp/appcast.xml", "not a URL"] {
                var invalid = good; invalid["SUFeedURL"] = feed
                XCTAssertFalse(AppUpdateService.hasUpdateConfiguration(invalid))
            }
            var invalid = good; invalid["SUPublicEDKey"] = "placeholder"
            XCTAssertFalse(AppUpdateService.hasUpdateConfiguration(invalid))
            invalid = good; invalid["CFBundleVersion"] = "unknown"
            XCTAssertFalse(AppUpdateService.hasUpdateConfiguration(invalid))
        }
    }
}
