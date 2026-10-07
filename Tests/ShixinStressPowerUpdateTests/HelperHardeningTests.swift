// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import Darwin
import Foundation
import XCTest
@testable import ShixinStressPowerCore

final class HelperHardeningTests: XCTestCase {
    func testRootNeverLaunchesSmartctl() {
        XCTAssertEqual(StorageTemperatureReader.smartctlCandidates(effectiveUserID: 0), [])
        XCTAssertTrue(
            StorageTemperatureReader.smartctlCandidates(effectiveUserID: 501).contains("/opt/homebrew/bin/smartctl"),
            "The app, running as the user, may still use a Homebrew smartctl"
        )
    }

    func testHelperSamplingServiceLaunchesNothingButPowermetrics() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: packageRoot.appendingPathComponent("Sources/ShixinStressPowerCore/HelperSampleService.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(source.contains("StorageTemperatureReader"), "Disk temperature is read by the app")
        XCTAssertFalse(source.contains("Process()"), "Foundation Process closes descriptors on its own schedule")
        XCTAssertFalse(source.contains("\"/usr/bin/pmset\""))
        XCTAssertEqual(source.components(separatedBy: "ChildProcessStream(").count - 1, 1)
        XCTAssertTrue(source.contains("\"/usr/bin/powermetrics\""))
    }

    func testChildProcessStreamReadsOutputAndReleasesEveryDescriptor() throws {
        let before = try openDescriptorCount()
        for _ in 0..<200 {
            let stream = try ChildProcessStream(executable: "/bin/echo", arguments: ["xinmai"])
            XCTAssertEqual(readToEnd(stream.readDescriptor), "xinmai\n")
            stream.finish()
            XCTAssertTrue(stream.hasExited())
        }
        XCTAssertEqual(try openDescriptorCount(), before, "Every pipe end must be closed exactly once")
    }

    func testChildProcessStreamStaysCorrectWhileFoundationProcessesRunAlongside() throws {
        let stop = ManagedFlag()
        let foundationErrors = ManagedCounter()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            defer { group.leave() }
            while !stop.isSet {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
                process.standardOutput = Pipe()
                process.standardError = Pipe()
                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    foundationErrors.increment()
                }
            }
        }

        for index in 0..<200 {
            let stream = try ChildProcessStream(executable: "/bin/echo", arguments: ["run-\(index)"])
            XCTAssertEqual(readToEnd(stream.readDescriptor), "run-\(index)\n")
            stream.finish()
        }
        stop.set()
        group.wait()
        XCTAssertEqual(foundationErrors.value, 0)
    }

    func testFinishStopsALongRunningChildPromptly() throws {
        let stream = try ChildProcessStream(executable: "/bin/sleep", arguments: ["30"])
        XCTAssertFalse(stream.hasExited())
        let started = Date()
        stream.finish()
        XCTAssertTrue(stream.hasExited())
        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
        stream.finish() // repeated calls are harmless
    }

    func testTerminationRequestFromAnotherThreadEndsTheChild() throws {
        let stream = try ChildProcessStream(executable: "/bin/sleep", arguments: ["30"])
        DispatchQueue.global().async { stream.requestTermination() }
        let deadline = Date().addingTimeInterval(2)
        while !stream.hasExited(), Date() < deadline {
            usleep(10_000)
        }
        XCTAssertTrue(stream.hasExited())
        XCTAssertEqual(readToEnd(stream.readDescriptor), "")
        stream.finish()
    }

    func testSpawnFailureReportsAndLeaksNothing() throws {
        let before = try openDescriptorCount()
        XCTAssertThrowsError(try ChildProcessStream(executable: "/nonexistent/xinmai-tool", arguments: []))
        XCTAssertEqual(try openDescriptorCount(), before)
    }

    func testOnlyDescriptorFailuresTriggerAFreshHelper() {
        XCTAssertTrue(HelperSampleService.isDescriptorFailure(HelperSampleServiceError.invalidStreamDescriptor))
        XCTAssertTrue(HelperSampleService.isDescriptorFailure(HelperSampleServiceError.streamReadFailed("x", EBADF)))
        XCTAssertTrue(HelperSampleService.isDescriptorFailure(ChildProcessStreamError.pipeFailed(EMFILE)))
        XCTAssertTrue(HelperSampleService.isDescriptorFailure(ChildProcessStreamError.spawnFailed(EBADF)))
        XCTAssertFalse(HelperSampleService.isDescriptorFailure(HelperSampleServiceError.streamReadFailed("x", EIO)))
        XCTAssertFalse(HelperSampleService.isDescriptorFailure(HelperSampleServiceError.streamTimedOut))
        XCTAssertFalse(HelperSampleService.isDescriptorFailure(HelperSampleServiceError.noSamples))
        XCTAssertFalse(HelperSampleService.isDescriptorFailure(ChildProcessStreamError.spawnFailed(ENOENT)))
    }

    func testPowerSourceStateFromIOKit() {
        let discharging = PowerSourceReader.snapshot(providingType: "Battery Power", sources: [
            ["Type": "InternalBattery", "Current Capacity": 47, "Max Capacity": 100, "Is Charging": false]
        ])
        XCTAssertEqual(discharging.source, "电池")
        XCTAssertEqual(discharging.batteryPercent, 47)
        XCTAssertEqual(discharging.isCharging, false, "A discharging battery is not charging")

        let charging = PowerSourceReader.snapshot(providingType: "AC Power", sources: [
            ["Type": "UPS", "Current Capacity": 10, "Max Capacity": 100],
            ["Type": "InternalBattery", "Current Capacity": 4_000, "Max Capacity": 5_000, "Is Charging": true]
        ])
        XCTAssertEqual(charging.source, "电源适配器")
        XCTAssertEqual(charging.batteryPercent, 80)
        XCTAssertEqual(charging.isCharging, true)

        let desktop = PowerSourceReader.snapshot(providingType: "AC Power", sources: [])
        XCTAssertEqual(desktop.source, "电源适配器")
        XCTAssertNil(desktop.batteryPercent)
        XCTAssertEqual(desktop.isCharging, false)

        XCTAssertEqual(PowerSourceReader.snapshot(providingType: nil, sources: []).source, "未知")
    }

    func testAppSuppliesTheDiskTemperature() {
        var fromNewHelper = sample()
        TelemetrySampler.applyLocalStorageTemperature(
            StorageTemperatureSnapshot(diskTemperatureC: 41, diskIdentifier: "disk0", sourceDetail: "smartctl /dev/disk0 SMART"),
            to: &fromNewHelper
        )
        XCTAssertEqual(fromNewHelper.diskTemperatureC, 41)
        XCTAssertEqual(fromNewHelper.diskTemperatureSourceDetail, "smartctl /dev/disk0 SMART")

        var fromOldHelper = sample()
        fromOldHelper.diskTemperatureC = 39
        fromOldHelper.diskTemperatureSourceDetail = "diskutil SMART"
        TelemetrySampler.applyLocalStorageTemperature(.unavailable, to: &fromOldHelper)
        XCTAssertEqual(fromOldHelper.diskTemperatureC, 39, "Keep an older Helper's reading until the app has its own")

        TelemetrySampler.applyLocalStorageTemperature(
            StorageTemperatureSnapshot(diskTemperatureC: 42, diskIdentifier: "disk0", sourceDetail: "diskutil SMART"),
            to: &fromOldHelper
        )
        XCTAssertEqual(fromOldHelper.diskTemperatureC, 42)

        var neither = sample()
        TelemetrySampler.applyLocalStorageTemperature(.unavailable, to: &neither)
        XCTAssertNil(neither.diskTemperatureC)
        XCTAssertEqual(neither.diskTemperatureSourceDetail, StorageTemperatureSnapshot.unavailable.sourceDetail)
    }

    private func sample() -> TelemetrySample {
        TelemetrySample(capturedAt: Date(), source: .powermetrics, sourceDetail: "test",
            thermalState: "Nominal", thermalPressure: nil, cpuPowerW: 4, gpuPowerW: 1,
            anePowerW: nil, packagePowerW: 5, cpuActivePercent: 20, gpuActivePercent: nil,
            eClusterFrequencyMHz: nil, pClusterFrequencyMHz: nil, gpuFrequencyMHz: nil,
            cpuTemperatureC: 50, gpuTemperatureC: 45, socTemperatureC: 52,
            powerSource: .unknown, isDegraded: false, message: nil)
    }

    private func openDescriptorCount() throws -> Int {
        try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count
    }

    private func readToEnd(_ descriptor: Int32) -> String {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while true {
            let count = read(descriptor, &buffer, buffer.count)
            if count > 0 {
                data.append(buffer, count: count)
            } else if count < 0, errno == EINTR {
                continue
            } else {
                break
            }
        }
        return String(decoding: data, as: UTF8.self)
    }
}

private final class ManagedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    var isSet: Bool { lock.lock(); defer { lock.unlock() }; return flag }
    func set() { lock.lock(); flag = true; lock.unlock() }
}

private final class ManagedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
    func increment() { lock.lock(); count += 1; lock.unlock() }
}
