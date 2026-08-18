// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import Darwin
import Foundation
import ShixinStressPowerCore

struct AppDiagnosticReport: Codable {
    var generatedAt: Date
    var appVersion: String
    var appBuild: String
    var helperExpectedVersion: String
    var helperInstalledVersion: String?
    var helperInstalled: Bool
    var launchDaemonPlistInstalled: Bool
    var launchdLoaded: Bool
    var socketReachable: Bool
    var helperVersionMatches: Bool
    var helperBundledBinaryMatches: Bool?
    var helperSamplingState: String?
    var helperSampleAgeSeconds: Double?
    var helperStatusDetail: String
    var powermetricsExecutableExists: Bool
    var currentProcessIsRoot: Bool
    var temperatureDiagnostics: TemperatureDiagnosticsSnapshot
    var smartDiskTemperatureC: Double?
    var smartDiskIdentifier: String?
    var smartDiskSource: String?
    var systemVersion: String
    var modelName: String
    var modelIdentifier: String
    var chip: String
    var currentSampleSource: String?
    var currentSampleDegraded: Bool?
    var currentSampleSequence: UInt64?
    var currentSampleAgeSeconds: Double?
    var historySchemaVersion: Int
    var historySessionCount: Int
    var historyBackupCount: Int
    var referencedCSVCount: Int?
    var orphanedCSVCount: Int?
    var historyRecoveryNotice: String?
    var recentLogLines: [String]
}

enum DiagnosticReportExporter {
    static func suggestedFilename(now: Date = Date()) -> String {
        "shixin-mac-stress-diagnostic-\(filenameTimestamp(now)).zip"
    }

    @MainActor
    static func export(
        appState: AppState,
        to destinationURL: URL
    ) throws -> URL {
        let report = makeReport(appState: appState)
        try writePackage(report: report, to: destinationURL)
        return destinationURL
    }

    @MainActor
    private static func makeReport(appState: AppState) -> AppDiagnosticReport {
        let helperStatus = appState.helperStatus
        let temperatureDiagnostics = HardwareDiagnostics.temperatureSnapshot()
        let storage = StorageTemperatureReader.read()
        let csvAudit = try? appState.store.auditCSVArchive(referencedBy: appState.sessions)
        let backupCount = ((try? FileManager.default.contentsOfDirectory(
            at: appState.store.historyBackupDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []).filter { $0.pathExtension.lowercased() == "json" }.count
        return AppDiagnosticReport(
            generatedAt: Date(),
            appVersion: ReleaseConstants.appVersion,
            appBuild: ReleaseConstants.appBuild,
            helperExpectedVersion: HelperConstants.helperVersion,
            helperInstalledVersion: helperStatus.helperVersion,
            helperInstalled: helperStatus.helperExists,
            launchDaemonPlistInstalled: helperStatus.plistExists,
            launchdLoaded: helperStatus.launchdLoaded,
            socketReachable: helperStatus.socketReachable,
            helperVersionMatches: helperStatus.versionMatches,
            helperBundledBinaryMatches: helperStatus.bundledBinaryMatches,
            helperSamplingState: helperStatus.samplingState,
            helperSampleAgeSeconds: helperStatus.sampleAgeSeconds,
            helperStatusDetail: helperStatus.detail,
            powermetricsExecutableExists: FileManager.default.isExecutableFile(atPath: "/usr/bin/powermetrics"),
            currentProcessIsRoot: geteuid() == 0,
            temperatureDiagnostics: temperatureDiagnostics,
            smartDiskTemperatureC: storage.diskTemperatureC,
            smartDiskIdentifier: storage.diskIdentifier,
            smartDiskSource: storage.sourceDetail,
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            modelName: hardwareValue("型号名称", in: appState.hardwareProfile) ?? "未知",
            modelIdentifier: hardwareValue("型号标识符", in: appState.hardwareProfile) ?? "未知",
            chip: hardwareValue("SoC", in: appState.hardwareProfile) ?? "Apple Silicon",
            currentSampleSource: appState.currentSample?.sourceDetail,
            currentSampleDegraded: appState.currentSample?.isDegraded,
            currentSampleSequence: appState.currentSample?.helperSampleSequence,
            currentSampleAgeSeconds: appState.telemetryAgeSeconds,
            historySchemaVersion: HistoryStore.currentSchemaVersion,
            historySessionCount: appState.sessions.count,
            historyBackupCount: backupCount,
            referencedCSVCount: csvAudit?.referencedFileCount,
            orphanedCSVCount: csvAudit?.orphanedFiles.count,
            historyRecoveryNotice: appState.store.lastRecoveryNotice,
            recentLogLines: recentLogLines(from: appState.store.logURL)
        )
    }

    private static func writePackage(report: AppDiagnosticReport, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory.appendingPathComponent("shixin-diagnostic-\(UUID().uuidString)", isDirectory: true)
        let packageDirectory = tempRoot.appendingPathComponent("SHIXIN-LAB-Mac-Stress-Diagnostic", isDirectory: true)
        try fileManager.createDirectory(at: packageDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempRoot) }

        let textURL = packageDirectory.appendingPathComponent("diagnostic-report.txt")
        try textReport(report).write(to: textURL, atomically: true, encoding: .utf8)

        let jsonURL = packageDirectory.appendingPathComponent("diagnostic-report.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(report).write(to: jsonURL, options: [.atomic])

        let logTailURL = packageDirectory.appendingPathComponent("recent-log-tail.txt")
        try (report.recentLogLines.joined(separator: "\n") + "\n").write(to: logTailURL, atomically: true, encoding: .utf8)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try zipDirectory(packageDirectory, to: destinationURL)
    }

    private static func textReport(_ report: AppDiagnosticReport) -> String {
        [
            "SHIXIN LAB · 「芯脉」 MacCore Monitor Diagnostic Report",
            "Generated At: \(ISO8601DateFormatter().string(from: report.generatedAt))",
            "",
            "App Version: \(report.appVersion) (build \(report.appBuild))",
            "Helper Expected Version: \(report.helperExpectedVersion)",
            "Helper Installed Version: \(report.helperInstalledVersion ?? "unknown")",
            "Helper Installed: \(yesNo(report.helperInstalled))",
            "LaunchDaemon Plist Installed: \(yesNo(report.launchDaemonPlistInstalled))",
            "launchd Loaded: \(yesNo(report.launchdLoaded))",
            "Socket Reachable: \(yesNo(report.socketReachable))",
            "Helper Version Matches: \(yesNo(report.helperVersionMatches))",
            "Helper Bundled Binary Matches: \(report.helperBundledBinaryMatches.map(yesNo) ?? "unknown")",
            "Helper Sampling State: \(report.helperSamplingState ?? "unknown")",
            "Helper Sample Age: \(number(report.helperSampleAgeSeconds)) s",
            "Helper Detail: \(report.helperStatusDetail)",
            "",
            "powermetrics Executable: \(yesNo(report.powermetricsExecutableExists))",
            "Current Process Is Root: \(yesNo(report.currentProcessIsRoot))",
            "",
            "System Version: \(report.systemVersion)",
            "Model: \(report.modelName)",
            "Model Identifier: \(report.modelIdentifier)",
            "Chip: \(report.chip)",
            "",
            "AppleSMC/HID Sensors: CPU \(report.temperatureDiagnostics.cpuSensorCount), GPU \(report.temperatureDiagnostics.gpuSensorCount), SoC \(report.temperatureDiagnostics.socSensorCount), All \(report.temperatureDiagnostics.allSensorCount), Fans \(report.temperatureDiagnostics.fanCount)",
            "Temperature Source: \(report.temperatureDiagnostics.sourceDetail)",
            "Current CPU/GPU/SoC Temperature: \(number(report.temperatureDiagnostics.cpuTemperatureC)) / \(number(report.temperatureDiagnostics.gpuTemperatureC)) / \(number(report.temperatureDiagnostics.socTemperatureC)) °C",
            "",
            "SMART Disk Temperature: \(number(report.smartDiskTemperatureC)) °C",
            "SMART Disk Identifier: \(report.smartDiskIdentifier ?? "unknown")",
            "SMART Disk Source: \(report.smartDiskSource ?? "unknown")",
            "",
            "Current Sample Source: \(report.currentSampleSource ?? "none")",
            "Current Sample Degraded: \(report.currentSampleDegraded.map(yesNo) ?? "unknown")",
            "Current Sample Sequence: \(report.currentSampleSequence.map(String.init) ?? "unknown")",
            "Current Sample Age: \(number(report.currentSampleAgeSeconds)) s",
            "",
            "History Schema: \(report.historySchemaVersion)",
            "History Sessions: \(report.historySessionCount)",
            "History Backups: \(report.historyBackupCount)",
            "Referenced CSV Files: \(report.referencedCSVCount.map(String.init) ?? "unknown")",
            "Orphaned CSV Files: \(report.orphanedCSVCount.map(String.init) ?? "unknown")",
            "History Recovery Notice: \(report.historyRecoveryNotice ?? "none")",
            "",
            "Recent 10 Log Lines:",
            report.recentLogLines.isEmpty ? "(no recent log lines)" : report.recentLogLines.joined(separator: "\n")
        ].joined(separator: "\n")
    }

    private static func zipDirectory(_ source: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", source.path, destination.path]
        let stderr = Pipe()
        process.standardOutput = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw DiagnosticReportError.zipFailed(message ?? "ditto exit \(process.terminationStatus)")
        }
    }

    private static func recentLogLines(from url: URL) -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return Array(text.components(separatedBy: .newlines).filter { !$0.isEmpty }.suffix(10))
    }

    private static func hardwareValue(_ title: String, in profile: HardwareProfile) -> String? {
        if let value = profile.headlineRows.first(where: { $0.title == title })?.value {
            return value
        }
        for section in profile.sections {
            if let value = section.rows.first(where: { $0.title == title })?.value {
                return value
            }
        }
        return nil
    }

    private static func filenameTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    private static func yesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }

    private static func number(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "unavailable" }
        return String(format: "%.2f", value)
    }
}

enum DiagnosticReportError: LocalizedError {
    case zipFailed(String)

    var errorDescription: String? {
        switch self {
        case .zipFailed(let message):
            return "诊断报告打包失败：\(message)"
        }
    }
}
