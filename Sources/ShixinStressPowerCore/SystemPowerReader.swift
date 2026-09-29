// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import IOKit

/// Presence distinguishes a new whole-machine sample (including unavailable)
/// from pre-0.3.2 samples that only measured the computing components.
public struct SystemPowerReading: Codable, Equatable {
    public var watts: Double?
    public var observedAt: Date
    public var source: String

    public init(watts: Double?, observedAt: Date, source: String = "AppleSmartBattery.SystemLoad") {
        self.watts = watts.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        self.observedAt = observedAt
        self.source = source
    }
}

public enum PowerMeasurementScope: String, Codable {
    case wholeMachine
    case legacyCompute

    public var peakTitle: String { self == .wholeMachine ? "整机峰值" : "计算部分峰值" }
    public var energyTitle: String { self == .wholeMachine ? "整机能耗" : "计算部分能耗" }

    public var title: String {
        switch self {
        case .wholeMachine: "整机功耗"
        case .legacyCompute: "计算部分功耗（旧记录）"
        }
    }
}

public enum SystemPowerReader {
    /// Read whole-system load through SMC, with explicitly labelled slow registry
    /// compatibility. Never substitute adapter input/rating or CPU+GPU.
    /// Both paths are local read-only calls; no subprocess, sudo or Helper update.
    public static func read() -> SystemPowerReading {
        let now = Date()
        // PSTR refreshes independently of the much slower battery telemetry cache.
        // Never use DC input (PDTR), charger rating, or CPU/GPU as system power.
        if let watts = SMCTemperatureReader.readSystemPowerW(), watts.isFinite, watts > 0 {
            return SystemPowerReading(watts: watts, observedAt: now, source: "AppleSMC.PSTR")
        }
        // Compatibility for hardware without PSTR. The UI explicitly labels this
        // source as a slow hardware reading rather than presenting it as real-time.
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else {
            return SystemPowerReading(watts: nil, observedAt: now)
        }
        defer { IOObjectRelease(service) }
        let value = IORegistryEntryCreateCFProperty(service, "PowerTelemetryData" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        return parse(value as? [String: Any], observedAt: now)
    }

    public static func parse(_ telemetry: [String: Any]?, observedAt: Date) -> SystemPowerReading {
        guard let value = telemetry?["SystemLoad"] as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID() else {
            return SystemPowerReading(watts: nil, observedAt: observedAt)
        }
        return SystemPowerReading(watts: value.doubleValue / 1000, observedAt: observedAt)
    }
}
