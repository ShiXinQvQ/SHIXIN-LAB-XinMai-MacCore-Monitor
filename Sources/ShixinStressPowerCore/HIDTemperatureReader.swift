// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import ShixinStressPowerHardwareBridge

struct HIDTemperatureSnapshot {
    var cpuTemperatureC: Double?
    var gpuTemperatureC: Double?
    var socTemperatureC: Double?
    var cpuSensorCount: Int
    var gpuSensorCount: Int
    var socSensorCount: Int
    var fanRPMs: [Double]
    var ssdTemperatureC: Double?
    var wifiTemperatureC: Double?
    var airflowTemperatureC: Double?
    var ambientTemperatureC: Double?
    var allSensorCount: Int
    var sourceDetail: String

    var hasAnyTemperature: Bool {
        cpuTemperatureC != nil || gpuTemperatureC != nil || socTemperatureC != nil
    }
}

enum HIDTemperatureReader {
    private static let cacheLock = NSLock()
    private static var cached: (date: Date, snapshot: HIDTemperatureSnapshot)?
    private static let cacheLifetime: TimeInterval = 1

    static func read() -> HIDTemperatureSnapshot {
        cacheLock.lock()
        if let cached, Date().timeIntervalSince(cached.date) < cacheLifetime {
            cacheLock.unlock()
            return cached.snapshot
        }
        cacheLock.unlock()

        let snapshot = readUncached()
        cacheLock.lock()
        cached = (Date(), snapshot)
        cacheLock.unlock()
        return snapshot
    }

    private static func readUncached() -> HIDTemperatureSnapshot {
        let smc = SMCTemperatureReader.read()
        #if arch(arm64)
        let rawSensors = ShixinAppleSiliconTemperatureSensors()
        var cpuValues: [Double] = []
        var gpuValues: [Double] = []
        var socValues: [Double] = []
        var allValidValues: [Double] = []

        for (name, number) in rawSensors {
            let value = number.doubleValue
            guard sanitize(value) != nil else { continue }
            allValidValues.append(value)

            if isCPUTemperatureSensor(name) {
                cpuValues.append(value)
            } else if isGPUTemperatureSensor(name) {
                gpuValues.append(value)
            } else if isSoCTemperatureSensor(name) {
                socValues.append(value)
            }
        }

        let cpuTemperature = smc.cpuTemperatureC ?? cpuValues.max()
        let gpuTemperature = smc.gpuTemperatureC ?? gpuValues.max()
        let socTemperature = smc.socTemperatureC ?? socValues.max()
        let cpuCount = smc.cpuSensorCount > 0 ? smc.cpuSensorCount : cpuValues.count
        let gpuCount = smc.gpuSensorCount > 0 ? smc.gpuSensorCount : gpuValues.count
        let socCount = smc.socSensorCount > 0 ? smc.socSensorCount : socValues.count

        return HIDTemperatureSnapshot(
            cpuTemperatureC: cpuTemperature,
            gpuTemperatureC: gpuTemperature,
            socTemperatureC: socTemperature,
            cpuSensorCount: cpuCount,
            gpuSensorCount: gpuCount,
            socSensorCount: socCount,
            fanRPMs: smc.fanRPMs,
            ssdTemperatureC: smc.ssdTemperatureC,
            wifiTemperatureC: smc.wifiTemperatureC,
            airflowTemperatureC: smc.airflowTemperatureC,
            ambientTemperatureC: smc.ambientTemperatureC,
            allSensorCount: allValidValues.count,
            sourceDetail: detail(
                smcCPUCount: smc.cpuSensorCount,
                smcGPUCount: smc.gpuSensorCount,
                smcSoCCount: smc.socSensorCount,
                hidCPUCount: cpuValues.count,
                hidGPUCount: gpuValues.count,
                hidSoCCount: socValues.count,
                smcDetail: smc.detail,
                allCount: allValidValues.count
            )
        )
        #else
        return HIDTemperatureSnapshot(
            cpuTemperatureC: smc.cpuTemperatureC,
            gpuTemperatureC: smc.gpuTemperatureC,
            socTemperatureC: smc.socTemperatureC,
            cpuSensorCount: smc.cpuSensorCount,
            gpuSensorCount: smc.gpuSensorCount,
            socSensorCount: smc.socSensorCount,
            fanRPMs: smc.fanRPMs,
            ssdTemperatureC: smc.ssdTemperatureC,
            wifiTemperatureC: smc.wifiTemperatureC,
            airflowTemperatureC: smc.airflowTemperatureC,
            ambientTemperatureC: smc.ambientTemperatureC,
            allSensorCount: 0,
            sourceDetail: smc.hasAnyTemperature ? smc.detail : "SMC/HID 温度传感器未返回可用值"
        )
        #endif
    }

    private static func isCPUTemperatureSensor(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasPrefix("pacc mtr temp")
            || lower.hasPrefix("eacc mtr temp")
            || (lower.contains("cpu") && lower.contains("temp"))
            || (lower.contains("performance core") && lower.contains("temp"))
            || (lower.contains("efficiency core") && lower.contains("temp"))
    }

    private static func isGPUTemperatureSensor(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasPrefix("gpu mtr temp")
            || (lower.contains("gpu") && lower.contains("temp"))
            || (lower.contains("gfx") && lower.contains("temp"))
    }

    private static func isSoCTemperatureSensor(_ name: String) -> Bool {
        let lower = name.lowercased()
        if lower.contains("battery") || lower.contains("nand") || lower.contains("airport") {
            return false
        }
        return lower.hasPrefix("pmu tdie")
            || lower.hasPrefix("pmu tdev")
            || lower == "pmu tcal"
            || lower.hasPrefix("pmgr soc die")
            || lower.hasPrefix("soc mtr temp")
            || lower.contains("soc die temp")
    }

    private static func sanitize(_ value: Double) -> Double? {
        guard value.isFinite, value >= 0, value < 140 else { return nil }
        return value
    }

    private static func detail(smcCPUCount: Int, smcGPUCount: Int, smcSoCCount: Int, hidCPUCount: Int, hidGPUCount: Int, hidSoCCount: Int, smcDetail: String, allCount: Int) -> String {
        if smcCPUCount > 0 || smcGPUCount > 0 || smcSoCCount > 0 {
            let hidSuffix = hidSoCCount > 0 ? " · HID SoC \(hidSoCCount)" : ""
            return "\(smcDetail)\(hidSuffix)"
        }
        if hidCPUCount > 0 || hidGPUCount > 0 {
            let socSuffix = hidSoCCount > 0 ? " · SoC \(hidSoCCount)" : ""
            return "Apple Silicon HID 温度传感器 · CPU \(hidCPUCount) / GPU \(hidGPUCount)\(socSuffix)"
        }
        if hidSoCCount > 0 {
            return "Apple Silicon HID SoC/PMU 温度 fallback · \(hidSoCCount) 个传感器"
        }
        if allCount > 0 {
            return "Apple Silicon HID 返回 \(allCount) 个温度传感器，但未匹配 CPU/GPU"
        }
        return "SMC/HID 温度传感器未返回可用值"
    }
}
