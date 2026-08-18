import Foundation

public struct HistoryArchive: Codable {
    public var schemaVersion: Int
    public var savedAt: Date
    public var sessions: [StressSessionSummary]

    public init(schemaVersion: Int = HistoryStore.currentSchemaVersion, savedAt: Date = Date(), sessions: [StressSessionSummary]) {
        self.schemaVersion = schemaVersion
        self.savedAt = savedAt
        self.sessions = sessions
    }
}

public struct HistoryCSVArchiveAudit {
    public var referencedFileCount: Int
    public var orphanedFiles: [URL]

    public init(referencedFileCount: Int, orphanedFiles: [URL]) {
        self.referencedFileCount = referencedFileCount
        self.orphanedFiles = orphanedFiles
    }
}

public enum HistoryCSVExportKind: Equatable {
    case fullSamples
    case archivedCurveSamples
}

public enum HistoryStoreError: LocalizedError {
    case noRecoverableHistory(primaryError: Error)

    public var errorDescription: String? {
        switch self {
        case .noRecoverableHistory(let primaryError):
            return "历史文件无法读取，现有滚动备份也未能恢复：\(primaryError.localizedDescription)"
        }
    }
}

public final class HistoryStore {
    public static let currentSchemaVersion = 3
    public let appSupportURL: URL
    public let sessionsURL: URL
    public let logURL: URL
    public let sessionCSVDirectoryURL: URL
    public let historyBackupDirectoryURL: URL
    public let corruptHistoryDirectoryURL: URL
    public private(set) var lastRecoveryNotice: String?

    private let fileManager: FileManager
    private let maximumHistoryBackups = 8

    public init(fileManager: FileManager = .default, appSupportURL: URL? = nil) {
        self.fileManager = fileManager
        if let appSupportURL {
            self.appSupportURL = appSupportURL
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.appSupportURL = base.appendingPathComponent("SHIXIN LAB Mac Stress & Power Monitor", isDirectory: true)
        }
        self.sessionsURL = self.appSupportURL.appendingPathComponent("stress-sessions.json")
        self.logURL = self.appSupportURL.appendingPathComponent("stress-monitor.log")
        self.sessionCSVDirectoryURL = self.appSupportURL.appendingPathComponent("Session CSV", isDirectory: true)
        self.historyBackupDirectoryURL = self.appSupportURL.appendingPathComponent("History Backups", isDirectory: true)
        self.corruptHistoryDirectoryURL = self.appSupportURL.appendingPathComponent("Recovered History", isDirectory: true)
    }

    public func ensureDirectories() throws {
        try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: sessionCSVDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: historyBackupDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: corruptHistoryDirectoryURL, withIntermediateDirectories: true)
    }

    public func loadSessions() throws -> [StressSessionSummary] {
        try ensureDirectories()
        lastRecoveryNotice = nil
        guard fileManager.fileExists(atPath: sessionsURL.path) else { return [] }
        do {
            let primaryData = try Data(contentsOf: sessionsURL)
            return try decodeSessions(from: primaryData)
        } catch {
            let primaryError = error
            let preservedURL = try? preserveCorruptPrimary()
            for backupURL in historyBackupURLs() {
                guard let backupData = try? Data(contentsOf: backupURL),
                      let recovered = try? decodeSessions(from: backupData) else {
                    continue
                }
                try writeArchive(recovered, createBackup: false)
                let preservedText = preservedURL.map { "；损坏文件已保留在 \($0.path)" } ?? ""
                lastRecoveryNotice = "历史记录已从滚动备份 \(backupURL.lastPathComponent) 恢复\(preservedText)。"
                return recovered
            }
            throw HistoryStoreError.noRecoverableHistory(primaryError: primaryError)
        }
    }

    public func saveSessions(_ sessions: [StressSessionSummary]) throws {
        try ensureDirectories()
        try writeArchive(sessions, createBackup: true)
    }

    public func appendSession(_ session: StressSessionSummary, to sessions: [StressSessionSummary]) throws -> [StressSessionSummary] {
        var updated = sessions
        updated.insert(session, at: 0)
        if updated.count > 120 {
            updated.removeLast(updated.count - 120)
        }
        try saveSessions(updated)
        try? appendLog("Session \(session.id.uuidString) ended: \(session.stopReason.rawValue), duration \(Formatters.seconds(session.durationSeconds)), peak \(Formatters.watts(session.peakPowerW))")
        return updated
    }

    public func saveFullSamplesCSV(for session: LiveSession) throws -> URL {
        try ensureDirectories()
        let filename = TelemetryCSVExporter.suggestedFilename(
            startedAt: session.startedAt,
            mode: session.configuration.mode
        )
        let url = uniqueFileURL(directory: sessionCSVDirectoryURL, filename: filename)
        try TelemetryCSVExporter.write(samples: session.samples, to: url)
        return url
    }

    public func relativeCSVPath(for url: URL) -> String? {
        guard url.pathExtension.lowercased() == "csv" else { return nil }
        let basePath = appSupportURL.resolvingSymlinksInPath().standardizedFileURL.path
        let targetPath = url.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = basePath.hasSuffix("/") ? basePath : basePath + "/"
        guard targetPath.hasPrefix(prefix) else { return nil }
        return String(targetPath.dropFirst(prefix.count))
    }

    public func fullSamplesCSVURL(for session: StressSessionSummary) -> URL? {
        if let relativePath = session.fullSampleCSVRelativePath,
           let resolved = resolvedRelativeCSVURL(relativePath),
           fileManager.fileExists(atPath: resolved.path) {
            return resolved
        }

        if let legacyPath = session.fullSampleCSVPath, !legacyPath.isEmpty {
            let legacyURL = URL(fileURLWithPath: legacyPath)
            let relocatedPath = "Session CSV/\(legacyURL.lastPathComponent)"
            if let relocated = resolvedRelativeCSVURL(relocatedPath),
               fileManager.fileExists(atPath: relocated.path) {
                return relocated
            }
            if let containedLegacyURL = resolvedLegacyCSVURL(legacyURL),
               fileManager.fileExists(atPath: containedLegacyURL.path) {
                return containedLegacyURL
            }
        }
        return nil
    }

    @discardableResult
    public func copyFullSamplesCSV(for session: StressSessionSummary, to destination: URL) throws -> HistoryCSVExportKind {
        try ensureDirectories()
        if let source = fullSamplesCSVURL(for: session) {
            if source.resolvingSymlinksInPath().standardizedFileURL == destination.resolvingSymlinksInPath().standardizedFileURL {
                return .fullSamples
            }
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
            return .fullSamples
        } else {
            try TelemetryCSVExporter.write(samples: session.samples, to: destination)
            return .archivedCurveSamples
        }
    }

    public func auditCSVArchive(referencedBy sessions: [StressSessionSummary]) throws -> HistoryCSVArchiveAudit {
        try ensureDirectories()
        let referenced = Set(sessions.compactMap { fullSamplesCSVURL(for: $0)?.standardizedFileURL.path })
        let files = try fileManager.contentsOfDirectory(
            at: sessionCSVDirectoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        let orphaned = files
            .filter { $0.pathExtension.lowercased() == "csv" }
            .filter { !referenced.contains($0.standardizedFileURL.path) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return HistoryCSVArchiveAudit(referencedFileCount: referenced.count, orphanedFiles: orphaned)
    }

    public func appendLog(_ line: String) throws {
        try ensureDirectories()
        let entry = "[\(ISO8601DateFormatter().string(from: Date()))] \(line)\n"
        let data = Data(entry.utf8)
        if fileManager.fileExists(atPath: logURL.path) {
            let handle = try FileHandle(forWritingTo: logURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: logURL, options: [.atomic])
        }
    }

    private func writeArchive(_ sessions: [StressSessionSummary], createBackup: Bool) throws {
        let archive = HistoryArchive(sessions: sessions)
        let data = try JSONEncoder.sessionEncoder.encode(archive)
        _ = try JSONDecoder.sessionDecoder.decode(HistoryArchive.self, from: data)
        if createBackup {
            try backupCurrentHistoryIfValid()
        }
        try data.write(to: sessionsURL, options: [.atomic])
    }

    private func decodeSessions(from data: Data) throws -> [StressSessionSummary] {
        if let archive = try? JSONDecoder.sessionDecoder.decode(HistoryArchive.self, from: data) {
            return archive.sessions
        }
        return try JSONDecoder.sessionDecoder.decode([StressSessionSummary].self, from: data)
    }

    private func backupCurrentHistoryIfValid() throws {
        guard fileManager.fileExists(atPath: sessionsURL.path) else { return }
        let data = try Data(contentsOf: sessionsURL)
        guard (try? decodeSessions(from: data)) != nil else {
            _ = try? preserveCorruptPrimary()
            return
        }
        let filename = "stress-sessions-\(filenameTimestamp(Date())).json"
        let backupURL = uniqueFileURL(directory: historyBackupDirectoryURL, filename: filename)
        try data.write(to: backupURL, options: [.atomic])
        pruneHistoryBackups()
    }

    private func historyBackupURLs() -> [URL] {
        let urls = (try? fileManager.contentsOfDirectory(
            at: historyBackupDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { modificationDate($0) > modificationDate($1) }
    }

    private func pruneHistoryBackups() {
        for url in historyBackupURLs().dropFirst(maximumHistoryBackups) {
            try? fileManager.removeItem(at: url)
        }
    }

    private func preserveCorruptPrimary() throws -> URL {
        let filename = "stress-sessions-corrupt-\(filenameTimestamp(Date())).json"
        let destination = uniqueFileURL(directory: corruptHistoryDirectoryURL, filename: filename)
        try fileManager.copyItem(at: sessionsURL, to: destination)
        return destination
    }

    private func resolvedRelativeCSVURL(_ relativePath: String) -> URL? {
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              URL(fileURLWithPath: relativePath).pathExtension.lowercased() == "csv" else {
            return nil
        }
        let resolved = appSupportURL
            .appendingPathComponent(relativePath)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let basePath = appSupportURL.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = basePath.hasSuffix("/") ? basePath : basePath + "/"
        guard resolved.path.hasPrefix(prefix) else { return nil }
        return resolved
    }

    private func resolvedLegacyCSVURL(_ url: URL) -> URL? {
        guard url.isFileURL, url.pathExtension.lowercased() == "csv" else { return nil }
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        let basePath = appSupportURL.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = basePath.hasSuffix("/") ? basePath : basePath + "/"
        guard resolved.path.hasPrefix(prefix) else { return nil }
        return resolved
    }

    private func uniqueFileURL(directory: URL, filename: String) -> URL {
        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var url = directory.appendingPathComponent(filename)
        var suffix = 2
        while fileManager.fileExists(atPath: url.path) {
            let suffixText = ext.isEmpty ? "\(base)-\(suffix)" : "\(base)-\(suffix).\(ext)"
            url = directory.appendingPathComponent(suffixText)
            suffix += 1
        }
        return url
    }

    private func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func filenameTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter.string(from: date)
    }
}

extension JSONEncoder {
    static var sessionEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var sessionDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
