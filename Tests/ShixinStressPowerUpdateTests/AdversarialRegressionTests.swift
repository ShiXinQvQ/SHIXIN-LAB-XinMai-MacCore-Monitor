// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import ShixinStressPowerCore
@testable import ShixinStressPower

final class AdversarialRegressionTests: XCTestCase {
    func testLocalFallbackCannotLeaveHelperMarkedHealthyAndRecoveryRestoresIt() {
        var status = HelperInstallStatus(helperExists: true, plistExists: true,
            launchdLoaded: true, socketReachable: true, helperVersion: "0.3.0-helper",
            versionMatches: true, bundledBinaryMatches: true, samplingState: "ready",
            sampleAgeSeconds: 0.1, installationDetail: "test")
        XCTAssertTrue(status.isUsable)
        var reading = sample()
        status.observe(reading)
        XCTAssertFalse(status.isUsable)
        XCTAssertEqual(status.samplingState, "restarting")
        XCTAssertFalse(status.detail.contains("ready"), "Technical details must track the new state too")
        reading.source = .powermetrics
        reading.isDegraded = false
        reading.helperSampleSequence = 42
        reading.helperSampleAgeSeconds = 0.1
        status.observe(reading)
        XCTAssertTrue(status.isUsable)
        reading.helperSampleAgeSeconds = 10
        status.observe(reading)
        XCTAssertFalse(status.isUsable)
        XCTAssertEqual(status.samplingState, "restarting")
    }

    func testOldHelperWithoutAgeStillRecoversAndMissingInstallationStaysMissing() {
        var status = HelperInstallStatus(helperExists: true, plistExists: true,
            launchdLoaded: true, socketReachable: true, helperVersion: "0.3.0-helper",
            versionMatches: true, bundledBinaryMatches: true, samplingState: "restarting",
            sampleAgeSeconds: nil, installationDetail: "test")
        var reading = sample()
        reading.source = .powermetrics
        reading.helperSampleSequence = 7
        status.observe(reading)
        // Legacy protocols without age have always been considered available.
        XCTAssertNil(status.samplingState)
        XCTAssertTrue(status.isUsable)
        status.socketReachable = false
        status.helperExists = false
        reading.source = .fallback
        status.observe(reading)
        XCTAssertFalse(status.isUsable)
    }

    func testExportFailurePreservesExistingDestination() throws {
        let root = try fixtureDirectory()
        let store = HistoryStore(appSupportURL: root.appendingPathComponent("history"))
        try store.ensureDirectories()
        let brokenSource = store.sessionCSVDirectoryURL.appendingPathComponent("broken.csv")
        try FileManager.default.createDirectory(at: brokenSource, withIntermediateDirectories: true)
        let destination = root.appendingPathComponent("precious.csv")
        let original = Data("existing user export\n".utf8)
        try original.write(to: destination)
        let summary = session(csv: "Session CSV/broken.csv")
        XCTAssertThrowsError(try store.copyFullSamplesCSV(for: summary, to: destination))
        XCTAssertEqual(try Data(contentsOf: destination), original)
    }

    func testExportReplacesContentsAndAllowsExportToItself() throws {
        let root = try fixtureDirectory()
        let store = HistoryStore(appSupportURL: root.appendingPathComponent("history"))
        try store.ensureDirectories()
        let source = store.sessionCSVDirectoryURL.appendingPathComponent("sample.csv")
        let destination = root.appendingPathComponent("export.csv")
        let csv = Data("capturedAt,cpuPowerW\n2026-09-25T00:00:00.500Z,12\n".utf8)
        try csv.write(to: source)
        try Data("previous export".utf8).write(to: destination)
        let summary = session(csv: "Session CSV/sample.csv")
        XCTAssertEqual(try store.copyFullSamplesCSV(for: summary, to: destination), .fullSamples)
        XCTAssertEqual(try Data(contentsOf: destination), csv)
        XCTAssertEqual(try store.copyFullSamplesCSV(for: summary, to: source), .fullSamples)
        XCTAssertEqual(try Data(contentsOf: source), csv)
    }

    private func fixtureDirectory() throws -> URL {
        // Retain evidence; do not permanently delete fixtures or touch real history.
        let base = ProcessInfo.processInfo.environment["SHIXIN_TEST_OUTPUT"]
            .map { URL(fileURLWithPath: $0) } ?? FileManager.default.temporaryDirectory
        let root = base.appendingPathComponent("adversarial-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func session(csv: String) -> StressSessionSummary {
        LiveSession(configuration: .default(logicalCPUs: 1)).makeSummary(
            stopReason: .user, fullSampleCSVRelativePath: csv)
    }

    private func sample() -> TelemetrySample {
        TelemetrySample(capturedAt: Date(), source: .fallback, sourceDetail: "test",
            thermalState: "Nominal", thermalPressure: nil, cpuPowerW: nil, gpuPowerW: nil,
            anePowerW: nil, packagePowerW: nil, cpuActivePercent: 20, gpuActivePercent: nil,
            eClusterFrequencyMHz: nil, pClusterFrequencyMHz: nil, gpuFrequencyMHz: nil,
            cpuTemperatureC: 60, gpuTemperatureC: 55, socTemperatureC: 65,
            powerSource: .unknown, isDegraded: true, message: "Helper failed")
    }
}
