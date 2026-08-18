// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum TelemetryCSVExporter {
    public static func csv(samples: [TelemetrySample]) -> String {
        let rows = samples.map(csvRow)

        return ([header.joined(separator: ",")] + rows).joined(separator: "\n") + "\n"
    }

    private static func csvRow(_ sample: TelemetrySample) -> String {
        let identity = [
            isoFormatter.string(from: sample.capturedAt),
            sample.source.rawValue,
            sample.sourceDetail,
            sample.thermalState,
            sample.thermalPressure ?? ""
        ]
        let powerAndActivity = [
            number(sample.cpuPowerW),
            number(sample.gpuPowerW),
            number(sample.anePowerW),
            number(sample.packagePowerW),
            number(sample.totalDisplayedPowerW),
            number(sample.cpuActivePercent),
            number(sample.gpuActivePercent),
            number(sample.eClusterFrequencyMHz),
            number(sample.pClusterFrequencyMHz),
            number(sample.gpuFrequencyMHz)
        ]
        let temperatures = [
            number(sample.cpuTemperatureC),
            number(sample.gpuTemperatureC),
            number(sample.socTemperatureC),
            number(sample.diskTemperatureC),
            number(sample.ssdTemperatureC),
            number(sample.wifiTemperatureC),
            number(sample.airflowTemperatureC),
            number(sample.ambientTemperatureC),
            fanRPMs(sample.fanRPMs)
        ]
        let batteryPercent = sample.powerSource.batteryPercent.map { String($0) } ?? ""
        let adapterWatts = sample.powerSource.adapterWatts.map { String($0) } ?? ""
        let sampleSequence = sample.helperSampleSequence.map { String($0) } ?? ""
        let sampleInterval = sample.samplingIntervalMilliseconds.map { String($0) } ?? ""
        let context: [String] = [
            sample.powerSource.source,
            batteryPercent,
            adapterWatts,
            sampleSequence,
            number(sample.helperSampleAgeSeconds),
            sampleInterval,
            sample.isDegraded ? "true" : "false",
            sample.message ?? ""
        ]
        return (identity + powerAndActivity + temperatures + context)
            .map(csvEscape)
            .joined(separator: ",")
    }

    public static func write(samples: [TelemetrySample], to url: URL) throws {
        try csv(samples: samples).write(to: url, atomically: true, encoding: .utf8)
    }

    public static func suggestedFilename(
        startedAt: Date,
        mode: StressMode?,
        prefix: String = "shixin-mac-stress-session"
    ) -> String {
        let modeText = mode.map { filenameComponent($0.rawValue) } ?? "samples"
        return "\(prefix)-\(filenameTimestamp(startedAt))-\(modeText).csv"
    }

    private static let header = [
        "capturedAt",
        "source",
        "sourceDetail",
        "thermalState",
        "thermalPressure",
        "cpuPowerW",
        "gpuPowerW",
        "anePowerW",
        "packagePowerW",
        "totalDisplayedPowerW",
        "cpuActivePercent",
        "gpuActivePercent",
        "eClusterFrequencyMHz",
        "pClusterFrequencyMHz",
        "gpuFrequencyMHz",
        "cpuTemperatureC",
        "gpuTemperatureC",
        "socTemperatureC",
        "diskTemperatureC",
        "ssdTemperatureC",
        "wifiTemperatureC",
        "airflowTemperatureC",
        "ambientTemperatureC",
        "fanRPMs",
        "powerSource",
        "batteryPercent",
        "adapterWatts",
        "helperSampleSequence",
        "helperSampleAgeSeconds",
        "samplingIntervalMilliseconds",
        "isDegraded",
        "message"
    ]

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func filenameTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    private static func filenameComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let scalars = value.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        return String(scalars)
            .lowercased()
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private static func fanRPMs(_ values: [Double]?) -> String {
        guard let values, !values.isEmpty else { return "" }
        return values.map { number($0) }.joined(separator: ";")
    }

    private static func number(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "" }
        return String(format: "%.3f", value)
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
