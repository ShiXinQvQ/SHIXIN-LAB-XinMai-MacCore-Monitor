// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
import Foundation
import SwiftUI
import AppKit
import ShixinStressPowerCore
@testable import ShixinStressPower

final class SystemPowerTests: XCTestCase {
    private func sample(_ seconds: Double, system: Double? = 50, legacy: Bool = false) -> TelemetrySample {
        var value = TelemetrySample(capturedAt: Date(timeIntervalSince1970: seconds), source: .powermetrics,
            sourceDetail: "fixture", thermalState: "Nominal", thermalPressure: nil,
            cpuPowerW: 11.1, gpuPowerW: 15.3, anePowerW: 0, packagePowerW: 26.4,
            cpuActivePercent: 30, gpuActivePercent: 50, eClusterFrequencyMHz: 1000,
            pClusterFrequencyMHz: 3000, gpuFrequencyMHz: 800, cpuTemperatureC: 60, gpuTemperatureC: 60,
            powerSource: .unknown, isDegraded: false, message: nil)
        if !legacy { value.systemPower = SystemPowerReading(watts: system, observedAt: value.capturedAt) }
        return value
    }

    func testChargingDischargingAndACUseSystemLoadNotPowerInput() {
        // Simulated budgets; no physical cable or charge settings are changed.
        let cases: [[String: Any]] = [
            ["SystemLoad": 53_390, "SystemPowerIn": 73_390, "BatteryPower": 20_000],
            ["SystemLoad": 53_390, "SystemPowerIn": 0, "BatteryPower": -53_390],
            ["SystemLoad": 53_390, "SystemPowerIn": 53_390, "BatteryPower": 0],
            ["SystemLoad": 53_390, "SystemPowerIn": 40_000, "BatteryPower": -13_390]
        ]
        for telemetry in cases {
            XCTAssertEqual(SystemPowerReader.parse(telemetry, observedAt: Date()).watts!, 53.39, accuracy: 0.00001)
        }
    }

    func testUnsupportedMalformedAndInvalidReadingsStayUnavailable() {
        for value: Any in [0, -1, Double.nan, Double.infinity, "53390", true, NSNull()] {
            XCTAssertNil(SystemPowerReader.parse(["SystemLoad": value], observedAt: Date()).watts)
        }
        XCTAssertNil(SystemPowerReader.parse(nil, observedAt: Date()).watts)
        XCTAssertNil(SystemPowerReader.parse(["SystemPowerIn": 100_000], observedAt: Date()).watts)
        let missing = sample(0, system: nil)
        XCTAssertEqual(missing.computePowerW, 26.4)
        XCTAssertNil(missing.totalDisplayedPowerW)
        XCTAssertEqual(missing.powerScope, .wholeMachine)
    }

    func testLegacyJSONDecodesWithoutRelabellingOldValues() throws {
        let data = try JSONEncoder().encode(sample(0, legacy: true))
        XCTAssertNil((try JSONSerialization.jsonObject(with: data) as! [String: Any])["systemPower"])
        let decoded = try JSONDecoder().decode(TelemetrySample.self, from: data)
        XCTAssertEqual(decoded.powerScope, .legacyCompute)
        XCTAssertEqual(decoded.totalDisplayedPowerW, 26.4)
        for power: Double? in [53.39, nil] {
            let new = try JSONDecoder().decode(TelemetrySample.self, from: JSONEncoder().encode(sample(0, system: power)))
            XCTAssertEqual(new.powerScope, .wholeMachine)
            XCTAssertEqual(new.totalDisplayedPowerW, power)
        }
    }

    func testPeakAverageAndEnergyUseSystemPowerAndRetainLegacyHistory() throws {
        var current = LiveSession(configuration: .default(logicalCPUs: 8))
        current.startedAt = Date(timeIntervalSince1970: 0)
        var legacy = current
        for t in 0...120 { current.append(sample(Double(t))); legacy.append(sample(Double(t), legacy: true)) }
        XCTAssertEqual(current.peakPowerW, 50)
        XCTAssertEqual(current.sustainedPower60sW!, 50, accuracy: 0.0001)
        XCTAssertEqual(current.estimatedEnergyWh!, 50 * 120 / 3600, accuracy: 0.0001)
        XCTAssertEqual(legacy.peakPowerW, 26.4)
        let newSummary = current.makeSummary(stopReason: .user, endedAt: Date(timeIntervalSince1970: 120))
        let oldSummary = legacy.makeSummary(stopReason: .user, endedAt: Date(timeIntervalSince1970: 120))
        XCTAssertEqual(newSummary.powerScope, .wholeMachine)
        XCTAssertEqual(oldSummary.powerScope, .legacyCompute)
        let archive = HistoryArchive(sessions: [newSummary, oldSummary])
        let decoded = try JSONDecoder().decode(HistoryArchive.self, from: JSONEncoder().encode(archive))
        XCTAssertEqual(decoded.sessions.map(\.powerScope), [.wholeMachine, .legacyCompute])
        XCTAssertEqual(decoded.sessions[1].peakPowerW, 26.4)
        XCTAssertEqual(newSummary.performanceReport?.stability.powerDropPercent, oldSummary.performanceReport?.stability.powerDropPercent)
    }

    func testMissingSystemPowerIsNotBridgedByEnergyOrChart() {
        var live = LiveSession(configuration: .default(logicalCPUs: 8))
        live.samples = [sample(0), sample(1, system: nil), sample(2)]
        XCTAssertNil(live.estimatedEnergyWh)
        let rows = TelemetryChartRows.power(live.samples).filter { $0.metric == L10n.t("整机功耗") }
        XCTAssertEqual(rows.map(\.value), [50, 50])
        XCTAssertEqual(rows.map(\.segment), [0, 1])
        let unavailable = RollingTelemetrySummary(samples: [sample(0, system: nil), sample(1, system: nil)], session: nil)
        XCTAssertNil(unavailable.peakPowerW)
        XCTAssertNil(unavailable.sustainedPower60sW)
        XCTAssertNil(unavailable.estimatedEnergyWh)
    }

    func testOverviewAndChartDoNotMixOldAndNewPowerScopes() {
        let samples = [sample(0, legacy: true), sample(1, system: 53.39), sample(2, system: nil)]
        let summary = RollingTelemetrySummary(samples: samples, session: nil)
        XCTAssertEqual(summary.peakPowerW, 53.39)
        XCTAssertEqual(summary.sustainedPower60sW, 53.39)
        let rows = TelemetryChartRows.power(samples)
        XCTAssertEqual(rows.filter { $0.metric == L10n.t("整机功耗") }.map(\.value), [53.39])
        XCTAssertEqual(rows.filter { $0.metric == L10n.t("计算部分功耗（旧记录）") }.map(\.value), [26.4])
        XCTAssertEqual(rows.filter { $0.metric == "CPU" }.map(\.value), [11.1, 11.1, 11.1])
    }

    func testCrossScopeComparisonDoesNotComputeMisleadingDelta() {
        let card = CompareMetricCard.numeric(title: "峰值功耗", a: 26.4, b: 53.39, unit: "W", decimals: 1,
            display: Formatters.watts, systemImage: "bolt", tint: .yellow, comparable: false)
        XCTAssertEqual(card.deltaText, L10n.t("功耗口径不同，不计算差值"))
    }

    func testCSVRecordsBothMeasurementAndScopeIncludingUnavailable() {
        let csv = TelemetryCSVExporter.csv(samples: [sample(0), sample(1, system: nil), sample(2, legacy: true)])
        XCTAssertTrue(csv.contains("powerMeasurementScope,systemPowerW,systemPowerSource,systemPowerObservedAt"))
        XCTAssertTrue(csv.contains("wholeMachine,50.000"))
        XCTAssertTrue(csv.contains("wholeMachine,,AppleSmartBattery.SystemLoad"))
        XCTAssertTrue(csv.contains("legacyCompute,,,"))
    }

    func testLiveRegistryReadIsReadOnlyAndBounded() {
        let start = ProcessInfo.processInfo.systemUptime
        let readings = (0..<20).map { _ in SystemPowerReader.read() }
        let elapsed = ProcessInfo.processInfo.systemUptime - start
        XCTAssertLessThan(elapsed, 2)
        print("SYSTEM_POWER_LIVE \(readings.last!.watts.map(String.init(describing:)) ?? "unavailable") W; 20 reads \(elapsed) s")
        for reading in readings { if let watts = reading.watts { XCTAssertTrue(watts.isFinite && watts > 0) } }
    }
    @MainActor
    func testOffscreenPowerCardsAndChartRender() throws {
        guard let directory = ProcessInfo.processInfo.environment["XINMAI_POWER_QA_DIR"] else { return }
        let samples = (0..<120).map { sample(Double($0), system: 50 + sin(Double($0) / 8) * 10) }
        let summary = RollingTelemetrySummary(samples: samples, session: nil)
        let view = VStack(spacing: 16) {
            HStack(spacing: 14) {
                MetricTile(title: "整机功耗", value: "53.4 W", detail: "系统负载 · 不含电池充电", systemImage: "bolt.fill", tint: .yellow)
                MetricTile(title: "CPU 功耗", value: "11.1 W", detail: "powermetrics", systemImage: "cpu", tint: .green)
                MetricTile(title: "GPU 功耗", value: "15.3 W", detail: "powermetrics", systemImage: "rectangle.3.group", tint: .blue)
                MetricTile(title: "整机峰值", value: Formatters.watts(summary.peakPowerW), detail: "最近采样峰值", systemImage: "chart.line.uptrend.xyaxis", tint: .orange)
            }
            LivePowerChart(samples: samples)
        }.padding(22).frame(width: 1000).background(Color(red: 0.035, green: 0.047, blue: 0.065)).preferredColorScheme(.dark).environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let cg = try XCTUnwrap(renderer.cgImage)
        let data = try XCTUnwrap(NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("power-cards-and-chart.png"))
    }

    func testIncompleteSessionNeverUsesPreSessionStatistics() {
        var session = LiveSession(configuration: .default(logicalCPUs: 8))
        session.samples = [sample(100, system: nil)]
        let summary = RollingTelemetrySummary(samples: [sample(0, system: 80), sample(1, system: 100)], session: session)
        XCTAssertNil(summary.peakPowerW)
        XCTAssertNil(summary.sustainedPower60sW)
        XCTAssertNil(summary.estimatedEnergyWh)
    }

    func testExistingUserHistoryDecodesReadOnlyWithUnchangedScope() throws {
        guard let path = ProcessInfo.processInfo.environment["XINMAI_HISTORY_READONLY"] else { return }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sessions: [StressSessionSummary]
        if let archive = try? decoder.decode(HistoryArchive.self, from: data) {
            sessions = archive.sessions
        } else { sessions = try decoder.decode([StressSessionSummary].self, from: data) }
        for session in sessions {
            XCTAssertEqual(session.powerScope, .legacyCompute)
            for sample in session.samples { XCTAssertEqual(sample.totalDisplayedPowerW, sample.computePowerW) }
        }
        print("READONLY_HISTORY_VERIFIED \(sessions.count) sessions")
    }

    func testLiveAppSamplerAddsSystemPowerWithAndWithoutHelper() async {
        let sampler = TelemetrySampler()
        for preferHelper in [false, true] {
            let sampled = await sampler.sample(preferHelper: preferHelper)
            XCTAssertEqual(sampled.powerScope, .wholeMachine)
            XCTAssertNotNil(sampled.systemPower)
            // Virtual machines and unsupported Macs legitimately have no sensor.
            // The opt-in cadence acceptance below requires PSTR on the real host.
            if ProcessInfo.processInfo.environment["XINMAI_POWER_CADENCE_DIR"] != nil {
                XCTAssertNotNil(sampled.systemPower?.watts)
            }
            XCTAssertEqual(sampled.totalDisplayedPowerW, sampled.systemPower?.watts)
            print("LIVE_SAMPLER helper=\(preferHelper) system=\(sampled.systemPower?.watts ?? -1) compute=\(sampled.computePowerW ?? -1)")
        }
    }

    func testPowerSourceDetailDisclosesSlowHardwareFallback() {
        var value = sample(0)
        value.systemPower = SystemPowerReading(watts: 40, observedAt: Date(), source: "AppleSMC.PSTR")
        XCTAssertEqual(value.systemPowerDetail, "系统负载 · 不含电池充电")
        value.systemPower = SystemPowerReading(watts: 40, observedAt: Date())
        XCTAssertEqual(value.systemPowerDetail, "系统负载 · 硬件低频更新")
        value.systemPower = SystemPowerReading(watts: nil, observedAt: Date())
        XCTAssertEqual(value.systemPowerDetail, "整机读数不可用")
    }

    func testLiveRefreshThroughSamplerGateAndPresentation() async throws {
        // Opt-in physical-host acceptance, not a claim about every Mac's sensors.
        guard let directory = ProcessInfo.processInfo.environment["XINMAI_POWER_CADENCE_DIR"] else { return }
        let sampler = TelemetrySampler()
        var gate = TelemetrySampleGate()
        var accepted: [TelemetrySample] = []
        var changes: [Double] = []
        var rows: [[String: Any]] = []
        var previousDisplay: String?
        for _ in 0..<40 {
            let start = ProcessInfo.processInfo.systemUptime
            let value = await sampler.sample()
            let took = ProcessInfo.processInfo.systemUptime - start
            let didAccept = gate.accept(value)
            if didAccept {
                accepted.append(value)
                let display = Formatters.watts(value.totalDisplayedPowerW)
                if display != previousDisplay { changes.append(start); previousDisplay = display }
            }
            rows.append(["uptime": start, "readSeconds": took, "accepted": didAccept,
                         "source": value.systemPower?.source ?? "nil",
                         "watts": value.totalDisplayedPowerW ?? -1,
                         "cpuWatts": value.cpuPowerW ?? -1, "gpuWatts": value.gpuPowerW ?? -1])
            try await Task.sleep(nanoseconds: UInt64(max(0.05, 0.5 - took) * 1_000_000_000))
        }
        let intervals = zip(changes, changes.dropFirst()).map { $1 - $0 }
        try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
            .write(to: URL(fileURLWithPath: directory).appendingPathComponent("app-pipeline-cadence.json"))
        XCTAssertGreaterThan(accepted.count, 25)
        XCTAssertTrue(accepted.allSatisfy { $0.systemPower?.source == "AppleSMC.PSTR" })
        XCTAssertGreaterThan(changes.count, 10, "Must observe new displayed values, not merely repeated reads")
        XCTAssertLessThan(intervals.max() ?? 100, 3)
        let chart = TelemetryChartRows.power(accepted).filter { $0.metric == L10n.t("整机功耗") }
        XCTAssertEqual(chart.map(\.value), accepted.compactMap(\.totalDisplayedPowerW))
        print("POWER_CADENCE_ACCEPTED polls=40 accepted=\(accepted.count) displayedChanges=\(changes.count) maxGap=\(intervals.max() ?? -1)s")
    }

}
