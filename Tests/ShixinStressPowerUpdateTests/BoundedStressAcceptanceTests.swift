// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
import Foundation
import ShixinStressPowerCore

final class BoundedStressAcceptanceTests: XCTestCase {
    func testBoundedRealStressStartStopAndRecovery() async throws {
        guard ProcessInfo.processInfo.environment["XINMAI_BOUNDED_STRESS"] == "1" else {
            throw XCTSkip("Real stress is opt-in; retain resources for concurrent work")
        }
        let sampler = TelemetrySampler()
        for mode in StressMode.allCases {
            guard ProcessInfo.processInfo.thermalState == .nominal || ProcessInfo.processInfo.thermalState == .fair else {
                throw XCTSkip("Host already has elevated thermal pressure")
            }
            let controller = StressController()
            let configuration = StressConfiguration(mode: mode, durationSeconds: 6,
                cpuWorkers: 1, gpuWorkItems: 16_384, gpuIterations: 16,
                thermalSeriousGraceSeconds: 1, stopOnCriticalThermalState: true)
            var changes = Set<Double>()
            var maximumStopSeconds = 0.0
            // GPU/combined bursts end after 150 ms, separated by 350 ms rests.
            // CPU-only stays on one worker for six seconds.
            for _ in 0..<12 {
                try await controller.start(configuration: configuration)
                try await Task.sleep(nanoseconds: mode == .cpu ? 500_000_000 : 150_000_000)
                if mode != .cpu {
                    let stopStart = ProcessInfo.processInfo.systemUptime
                    await controller.stop()
                    maximumStopSeconds = max(maximumStopSeconds, ProcessInfo.processInfo.systemUptime - stopStart)
                }
                let sample = await sampler.sample()
                if let power = sample.systemPower?.watts { changes.insert(power) }
                if ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical {
                    await controller.stop()
                    XCTFail("Stopped this task's stress at elevated thermal pressure")
                    return
                }
                if mode != .cpu { try await Task.sleep(nanoseconds: 350_000_000) }
            }
            let stopStart = ProcessInfo.processInfo.systemUptime
            await controller.stop()
            await controller.stop() // Repeated stop must remain safe.
            let stopDuration = ProcessInfo.processInfo.systemUptime - stopStart
            maximumStopSeconds = max(maximumStopSeconds, stopDuration)
            XCTAssertLessThan(maximumStopSeconds, 1.5)
            let failure = await controller.takeRuntimeFailure()
            XCTAssertNil(failure)
            XCTAssertGreaterThan(changes.count, 2)
            print("BOUNDED_STRESS mode=\(mode.rawValue) uniqueSystemReadings=\(changes.count) maxActualStopSeconds=\(maximumStopSeconds)")
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
}
