// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import ShixinStressPowerCore
@testable import ShixinStressPower

final class TelemetryChartRowsTests: XCTestCase {
    func testUnavailableFanDoesNotBecomeAZeroRPMMeasurement() {
        var missing = sample(0, power: nil)
        missing.fanRPMs = nil
        XCTAssertTrue(TelemetryChartRows.fans([missing]).isEmpty)
        missing.fanRPMs = []
        XCTAssertTrue(TelemetryChartRows.fans([missing]).isEmpty)
        missing.fanRPMs = [0]
        XCTAssertEqual(TelemetryChartRows.fans([missing]).map(\.value), [0], "A measured stopped fan is a real zero")
    }

    func testHelperWaitingForFirstPowerSampleKeepsFreshSensors() {
        var gate = TelemetrySampleGate()
        var first = sample(0, power: nil)
        first.helperSampleSequence = 0
        var second = sample(0.5, power: nil)
        second.helperSampleSequence = 0
        second.cpuTemperatureC = 65
        XCTAssertTrue(gate.accept(first))
        XCTAssertTrue(gate.accept(second), "Sequence zero is not an immutable power snapshot; sensors still advance")
    }

    func testIdleHelperCacheDoesNotEnterANewChart() {
        var gate = TelemetrySampleGate()
        var cached = sample(0, power: 10)
        cached.helperSampleSequence = 40
        cached.helperSampleAgeSeconds = 29
        XCTAssertFalse(gate.accept(cached))
        var fresh = sample(30, power: 12)
        fresh.helperSampleSequence = 41
        fresh.helperSampleAgeSeconds = 0.2
        XCTAssertTrue(gate.accept(fresh))
        XCTAssertFalse(gate.accept(fresh))
        // A restarted Helper may reset its sequence counter.
        fresh.helperSampleSequence = 1
        XCTAssertTrue(gate.accept(fresh))
    }

    func testRealLocalFallbackIsPreservedAsAMissingPowerReading() {
        var gate = TelemetrySampleGate()
        let local = sample(1, power: nil)
        XCTAssertTrue(gate.accept(local))
        var legacy = sample(2, power: 10)
        legacy.helperSampleSequence = 2
        legacy.helperSampleAgeSeconds = nil
        XCTAssertTrue(gate.accept(legacy))
    }

    func testDelayedHelperAfterLocalFallbackDoesNotDrawBackwards() {
        let samples = [sample(0, power: 10, activity: 40),
                       sample(1.2, power: nil, activity: 20),
                       sample(1, power: 12, activity: 60),
                       sample(2, power: 14, activity: 50)]
        let rows = TelemetryChartRows.activity(samples).filter { $0.metric == "CPU" }
        XCTAssertEqual(rows.map(\.date), [samples[0], samples[2], samples[1], samples[3]].map(\.capturedAt))
        XCTAssertEqual(rows.map(\.value), [40, 60, 20, 50])
        XCTAssertEqual(samples.map(\.cpuActivePercent), [40, 20, 60, 50], "Do not mutate raw records")
    }

    func testMissingPowerStillBreaksTheLineAfterOrdering() {
        let samples = [sample(0, power: 10), sample(1.2, power: nil),
                       sample(1, power: 12), sample(2, power: 14)]
        let rows = TelemetryChartRows.power(samples).filter { $0.metric == "CPU" }
        XCTAssertEqual(rows.map(\.value), [10, 12, 14])
        XCTAssertEqual(rows.map(\.segment), [0, 0, 1], "Keep the real missing-value gap at 1.2 seconds")
    }

    func testEqualTimestampsKeepTheirOriginalOrderAndValues() {
        let samples = [sample(1, power: 12, activity: 40), sample(0, power: 10, activity: 20),
                       sample(1, power: 14, activity: 60)]
        let rows = TelemetryChartRows.activity(samples).filter { $0.metric == "CPU" }
        XCTAssertEqual(rows.map(\.value), [20, 40, 60])
        XCTAssertEqual(rows.count, 3, "Do not invent timestamps or discard distinct readings")
    }

    func testKnownArchiveGapSurvivesOutOfOrderInput() {
        let a = sample(0, power: 10), b = sample(5, power: 20)
        let rows = TelemetryChartRows.power([b, a], knownGaps: [
            TelemetrySamplingGap(startedAt: a.capturedAt, endedAt: b.capturedAt)
        ]).filter { $0.metric == "CPU" }
        XCTAssertEqual(rows.map(\.date), [a.capturedAt, b.capturedAt])
        XCTAssertEqual(rows.map(\.segment), [0, 1])
    }

    func testNormalInputAndRecentWindowRemainUnchanged() {
        let samples = [sample(0, power: 1), sample(0.5, power: 2), sample(1, power: 3)]
        let rows = TelemetryChartRows.power(samples, sampleLimit: 2).filter { $0.metric == "CPU" }
        XCTAssertEqual(rows.map(\.date), samples.suffix(2).map(\.capturedAt))
        XCTAssertEqual(rows.map(\.value), [2, 3])
        XCTAssertEqual(rows.map(\.segment), [0, 0])
    }

    func testAllMetricFamiliesUseTimeOrder() {
        let samples = [sample(2, power: 3), sample(0, power: 1), sample(1, power: 2)]
        let families = [TelemetryChartRows.power(samples), TelemetryChartRows.coreTemperature(samples),
                        TelemetryChartRows.moduleTemperature(samples), TelemetryChartRows.frequency(samples),
                        TelemetryChartRows.activity(samples), TelemetryChartRows.fans(samples)]
        for family in families {
            for rows in Dictionary(grouping: family, by: \.metric).values {
                XCTAssertEqual(rows.map(\.date), rows.map(\.date).sorted())
            }
        }
    }

    private func sample(_ seconds: Double, power: Double?, activity: Double = 30) -> TelemetrySample {
        TelemetrySample(capturedAt: Date(timeIntervalSince1970: 1_790_000_000 + seconds),
                        source: power == nil ? .fallback : .powermetrics, sourceDetail: "test",
                        thermalState: "Nominal", thermalPressure: nil, cpuPowerW: power,
                        gpuPowerW: power, anePowerW: nil, packagePowerW: power,
                        cpuActivePercent: activity, gpuActivePercent: power == nil ? nil : 50,
                        eClusterFrequencyMHz: power == nil ? nil : 1800,
                        pClusterFrequencyMHz: power == nil ? nil : 3600,
                        gpuFrequencyMHz: power == nil ? nil : 500,
                        cpuTemperatureC: 60, gpuTemperatureC: 55, socTemperatureC: 70,
                        powerSource: .unknown, isDegraded: power == nil, message: nil,
                        fanRPMs: [2000, 2100], ssdTemperatureC: 40, diskTemperatureC: 35,
                        wifiTemperatureC: 45, airflowTemperatureC: 30, ambientTemperatureC: 25)
    }
}
