import Foundation

public struct NetworkSpeedTestRecord: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let completedAt: Date
    public let downloadMbps: Double
    public let uploadMbps: Double
    public let latencyMilliseconds: Double
    public let jitterMilliseconds: Double?
    public let responsivenessRPM: Int?
    public let downlinkResponsivenessRPM: Int?
    public let uplinkResponsivenessRPM: Int?
    public let downloadedBytes: Int64?
    public let uploadedBytes: Int64?
    public let interfaceName: String?
    public let serverName: String
    public let engineName: String

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        completedAt: Date,
        downloadMbps: Double,
        uploadMbps: Double,
        latencyMilliseconds: Double,
        jitterMilliseconds: Double?,
        responsivenessRPM: Int?,
        downlinkResponsivenessRPM: Int?,
        uplinkResponsivenessRPM: Int?,
        downloadedBytes: Int64?,
        uploadedBytes: Int64?,
        interfaceName: String?,
        serverName: String,
        engineName: String = "macOS networkQuality"
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.downloadMbps = downloadMbps
        self.uploadMbps = uploadMbps
        self.latencyMilliseconds = latencyMilliseconds
        self.jitterMilliseconds = jitterMilliseconds
        self.responsivenessRPM = responsivenessRPM
        self.downlinkResponsivenessRPM = downlinkResponsivenessRPM
        self.uplinkResponsivenessRPM = uplinkResponsivenessRPM
        self.downloadedBytes = downloadedBytes
        self.uploadedBytes = uploadedBytes
        self.interfaceName = interfaceName
        self.serverName = serverName
        self.engineName = engineName
    }

    public var durationSeconds: TimeInterval {
        max(0, completedAt.timeIntervalSince(startedAt))
    }
}

public struct NetworkQualityMeasurement: Equatable, Sendable {
    public let downloadMbps: Double
    public let uploadMbps: Double
    public let latencyMilliseconds: Double?
    public let responsivenessRPM: Int?
    public let downlinkResponsivenessRPM: Int?
    public let uplinkResponsivenessRPM: Int?
    public let downloadedBytes: Int64?
    public let uploadedBytes: Int64?
    public let interfaceName: String?
    public let testEndpointHost: String?

    public init(
        downloadMbps: Double,
        uploadMbps: Double,
        latencyMilliseconds: Double?,
        responsivenessRPM: Int?,
        downlinkResponsivenessRPM: Int?,
        uplinkResponsivenessRPM: Int?,
        downloadedBytes: Int64?,
        uploadedBytes: Int64?,
        interfaceName: String?,
        testEndpointHost: String?
    ) {
        self.downloadMbps = downloadMbps
        self.uploadMbps = uploadMbps
        self.latencyMilliseconds = latencyMilliseconds
        self.responsivenessRPM = responsivenessRPM
        self.downlinkResponsivenessRPM = downlinkResponsivenessRPM
        self.uplinkResponsivenessRPM = uplinkResponsivenessRPM
        self.downloadedBytes = downloadedBytes
        self.uploadedBytes = uploadedBytes
        self.interfaceName = interfaceName
        self.testEndpointHost = testEndpointHost
    }
}

public struct NetworkQualityLiveMeasurement: Equatable, Sendable {
    public let fractionCompleted: Double?
    public let downloadMbps: Double?
    public let uploadMbps: Double?
    public let latencyMilliseconds: Double?
    public let responsivenessRPM: Int?
    public let downlinkResponsivenessRPM: Int?
    public let uplinkResponsivenessRPM: Int?
    public let downloadedBytes: Int64?
    public let uploadedBytes: Int64?
    public let interfaceName: String?
    public let testEndpointHost: String?

    public init(
        fractionCompleted: Double?,
        downloadMbps: Double?,
        uploadMbps: Double?,
        latencyMilliseconds: Double?,
        responsivenessRPM: Int?,
        downlinkResponsivenessRPM: Int?,
        uplinkResponsivenessRPM: Int?,
        downloadedBytes: Int64?,
        uploadedBytes: Int64?,
        interfaceName: String?,
        testEndpointHost: String?
    ) {
        self.fractionCompleted = fractionCompleted
        self.downloadMbps = downloadMbps
        self.uploadMbps = uploadMbps
        self.latencyMilliseconds = latencyMilliseconds
        self.responsivenessRPM = responsivenessRPM
        self.downlinkResponsivenessRPM = downlinkResponsivenessRPM
        self.uplinkResponsivenessRPM = uplinkResponsivenessRPM
        self.downloadedBytes = downloadedBytes
        self.uploadedBytes = uploadedBytes
        self.interfaceName = interfaceName
        self.testEndpointHost = testEndpointHost
    }
}

public enum NetworkSpeedTestError: LocalizedError, Equatable {
    case invalidOutput
    case missingMeasurement
    case networkQualityFailure(code: Int, domain: String?, description: String?)
    case processFailed(status: Int32, message: String?)
    case alreadyRunning

    public var errorDescription: String? {
        switch self {
        case .invalidOutput:
            return "无法解析 macOS 返回的测速结果。"
        case .missingMeasurement:
            return "测速已结束，但没有获得完整的下载与上传结果。"
        case let .networkQualityFailure(code, domain, description):
            if let description, !description.isEmpty {
                return "网络测速失败：\(description)"
            }
            if code == -1003 || domain == "NSURLErrorDomain" {
                return "无法连接测速服务，请检查网络、DNS 或代理设置后重试。"
            }
            return "网络测速失败（\(domain ?? "系统错误") \(code)）。"
        case let .processFailed(status, message):
            if let message, !message.isEmpty {
                return "系统测速工具运行失败：\(message)"
            }
            return "系统测速工具运行失败（退出码 \(status)）。"
        case .alreadyRunning:
            return "已有测速任务正在运行。"
        }
    }
}

public enum NetworkQualityParser {
    public static func latestLiveMeasurement(in data: Data) -> NetworkQualityLiveMeasurement? {
        for object in jsonObjects(in: data).reversed() {
            let eventType = string(object, keys: ["event_type"])?.lowercased()
            let isLiveEvent = eventType == "progress" || eventType == "final"
            guard isLiveEvent || containsLiveFields(object) else { continue }

            let downlinkRPM = integer(
                object,
                keys: ["downlink_responsiveness_rpm", "dl_responsiveness"]
            )
            let uplinkRPM = integer(
                object,
                keys: ["uplink_responsiveness_rpm", "ul_responsiveness"]
            )
            let combinedRPM = integer(object, keys: ["responsiveness"])
                ?? [downlinkRPM, uplinkRPM].compactMap { $0 }.min()

            return NetworkQualityLiveMeasurement(
                fractionCompleted: normalizedProgress(number(
                    object,
                    keys: ["progress", "fraction_completed", "percent_complete"]
                )),
                downloadMbps: downloadMbps(object),
                uploadMbps: uploadMbps(object),
                latencyMilliseconds: number(object, keys: ["idle_latency_ms", "base_rtt"]),
                responsivenessRPM: combinedRPM,
                downlinkResponsivenessRPM: downlinkRPM,
                uplinkResponsivenessRPM: uplinkRPM,
                downloadedBytes: int64(
                    object,
                    keys: ["downlink_bytes_transferred", "dl_bytes_transferred"]
                ),
                uploadedBytes: int64(
                    object,
                    keys: ["uplink_bytes_transferred", "ul_bytes_transferred"]
                ),
                interfaceName: string(object, keys: ["interface_name", "interface"]),
                testEndpointHost: endpointHost(string(object, keys: ["test_endpoint"]))
            )
        }
        return nil
    }

    public static func parse(data: Data) throws -> NetworkQualityMeasurement {
        let objects = jsonObjects(in: data)
        guard !objects.isEmpty else {
            throw NetworkSpeedTestError.invalidOutput
        }

        let result = objects.last(where: isFinalObject)
            ?? objects.last(where: containsMeasurement)
            ?? objects.last!

        if let errorCode = integer(result, keys: ["error_code"]),
           errorCode != 0,
           !containsMeasurement(result) {
            throw NetworkSpeedTestError.networkQualityFailure(
                code: errorCode,
                domain: string(result, keys: ["error_domain"]),
                description: string(result, keys: ["error_description", "localized_description"])
            )
        }

        guard let downloadMbps = downloadMbps(result),
              let uploadMbps = uploadMbps(result),
              downloadMbps >= 0,
              uploadMbps >= 0 else {
            throw NetworkSpeedTestError.missingMeasurement
        }

        let downlinkRPM = integer(
            result,
            keys: ["downlink_responsiveness_rpm", "dl_responsiveness"]
        )
        let uplinkRPM = integer(
            result,
            keys: ["uplink_responsiveness_rpm", "ul_responsiveness"]
        )
        let combinedRPM = integer(result, keys: ["responsiveness"])
            ?? [downlinkRPM, uplinkRPM].compactMap { $0 }.min()

        return NetworkQualityMeasurement(
            downloadMbps: downloadMbps,
            uploadMbps: uploadMbps,
            latencyMilliseconds: number(result, keys: ["idle_latency_ms", "base_rtt"]),
            responsivenessRPM: combinedRPM,
            downlinkResponsivenessRPM: downlinkRPM,
            uplinkResponsivenessRPM: uplinkRPM,
            downloadedBytes: int64(result, keys: ["downlink_bytes_transferred", "dl_bytes_transferred"]),
            uploadedBytes: int64(result, keys: ["uplink_bytes_transferred", "ul_bytes_transferred"]),
            interfaceName: string(result, keys: ["interface_name", "interface"]),
            testEndpointHost: endpointHost(string(result, keys: ["test_endpoint"]))
        )
    }

    private static func downloadMbps(_ object: [String: Any]) -> Double? {
        if let value = number(object, keys: ["downlink_capacity_mbps", "download_capacity_mbps"]) {
            return value
        }
        if let bitsPerSecond = number(object, keys: ["dl_throughput", "downlink_throughput"]) {
            return bitsPerSecond / 1_000_000
        }
        return nil
    }

    private static func uploadMbps(_ object: [String: Any]) -> Double? {
        if let value = number(object, keys: ["uplink_capacity_mbps", "upload_capacity_mbps"]) {
            return value
        }
        if let bitsPerSecond = number(object, keys: ["ul_throughput", "uplink_throughput"]) {
            return bitsPerSecond / 1_000_000
        }
        return nil
    }

    private static func isFinalObject(_ object: [String: Any]) -> Bool {
        string(object, keys: ["event_type"])?.lowercased() == "final"
    }

    private static func containsMeasurement(_ object: [String: Any]) -> Bool {
        downloadMbps(object) != nil || uploadMbps(object) != nil
    }

    private static func containsLiveFields(_ object: [String: Any]) -> Bool {
        containsMeasurement(object)
            || number(
                object,
                keys: [
                    "idle_latency_ms",
                    "base_rtt",
                    "responsiveness",
                    "downlink_responsiveness_rpm",
                    "uplink_responsiveness_rpm",
                    "dl_responsiveness",
                    "ul_responsiveness",
                    "downlink_bytes_transferred",
                    "uplink_bytes_transferred",
                    "dl_bytes_transferred",
                    "ul_bytes_transferred"
                ]
            ) != nil
            || string(object, keys: ["interface_name", "interface", "test_endpoint"]) != nil
    }

    private static func normalizedProgress(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        let fraction = value > 1 ? value / 100 : value
        return min(max(fraction, 0), 1)
    }

    private static func endpointHost(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        if let host = URL(string: value)?.host, !host.isEmpty {
            return host
        }
        return nil
    }

    private static func number(_ object: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = object[key] as? NSNumber {
                return value.doubleValue
            }
            if let value = object[key] as? String,
               let parsed = Double(value) {
                return parsed
            }
        }
        return nil
    }

    private static func integer(_ object: [String: Any], keys: [String]) -> Int? {
        number(object, keys: keys).map { Int($0.rounded()) }
    }

    private static func int64(_ object: [String: Any], keys: [String]) -> Int64? {
        number(object, keys: keys).map { Int64($0.rounded()) }
    }

    private static func string(_ object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key] as? String {
                return value
            }
        }
        return nil
    }

    private static func jsonObjects(in data: Data) -> [[String: Any]] {
        if let root = try? JSONSerialization.jsonObject(with: data) {
            if let dictionary = root as? [String: Any] {
                return [dictionary]
            }
            if let array = root as? [[String: Any]] {
                return array
            }
        }

        return topLevelJSONObjectSlices(in: data).compactMap { slice in
            (try? JSONSerialization.jsonObject(with: slice)) as? [String: Any]
        }
    }

    private static func topLevelJSONObjectSlices(in data: Data) -> [Data] {
        let bytes = [UInt8](data)
        var slices: [Data] = []
        var start: Int?
        var depth = 0
        var isInsideString = false
        var isEscaped = false

        for (index, byte) in bytes.enumerated() {
            if start != nil {
                if isInsideString {
                    if isEscaped {
                        isEscaped = false
                    } else if byte == 0x5C {
                        isEscaped = true
                    } else if byte == 0x22 {
                        isInsideString = false
                    }
                    continue
                }

                if byte == 0x22 {
                    isInsideString = true
                } else if byte == 0x7B {
                    depth += 1
                } else if byte == 0x7D {
                    depth -= 1
                    if depth == 0, let startIndex = start {
                        slices.append(Data(bytes[startIndex...index]))
                        start = nil
                        isInsideString = false
                        isEscaped = false
                    }
                }
            } else if byte == 0x7B {
                start = index
                depth = 1
            }
        }

        return slices
    }
}

public struct NetworkSpeedHistoryArchive: Codable, Sendable {
    public static let currentSchemaVersion = 1
    public let schemaVersion: Int
    public let savedAt: Date
    public let records: [NetworkSpeedTestRecord]

    public init(
        schemaVersion: Int = NetworkSpeedHistoryArchive.currentSchemaVersion,
        savedAt: Date = Date(),
        records: [NetworkSpeedTestRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.savedAt = savedAt
        self.records = records
    }
}

public final class NetworkSpeedHistoryStore: @unchecked Sendable {
    public let appSupportURL: URL
    public let historyURL: URL

    private let fileManager: FileManager
    private let maximumRecords: Int
    private let lock = NSLock()
    private let backupURL: URL
    private let corruptDirectoryURL: URL

    public init(
        fileManager: FileManager = .default,
        appSupportURL: URL? = nil,
        maximumRecords: Int = 50
    ) {
        self.fileManager = fileManager
        if let appSupportURL {
            self.appSupportURL = appSupportURL
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.appSupportURL = base.appendingPathComponent(
                "SHIXIN LAB Mac Stress & Power Monitor",
                isDirectory: true
            )
        }
        self.historyURL = self.appSupportURL.appendingPathComponent("network-speed-history.json")
        self.backupURL = self.appSupportURL.appendingPathComponent("network-speed-history.previous.json")
        self.corruptDirectoryURL = self.appSupportURL.appendingPathComponent(
            "Recovered Network History",
            isDirectory: true
        )
        self.maximumRecords = max(1, maximumRecords)
    }

    public func load() throws -> [NetworkSpeedTestRecord] {
        try withLock {
            try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            return try loadRecordsRecoveringIfNeeded()
        }
    }

    @discardableResult
    public func append(_ record: NetworkSpeedTestRecord) throws -> [NetworkSpeedTestRecord] {
        try withLock {
            try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            var records = try loadRecordsRecoveringIfNeeded()
            records.removeAll { $0.id == record.id }
            records.append(record)
            records.sort { $0.completedAt > $1.completedAt }
            if records.count > maximumRecords {
                records.removeLast(records.count - maximumRecords)
            }
            try writeRecords(records)
            return records
        }
    }

    private func loadRecordsRecoveringIfNeeded() throws -> [NetworkSpeedTestRecord] {
        guard fileManager.fileExists(atPath: historyURL.path) else { return [] }
        do {
            return try decodeRecords(Data(contentsOf: historyURL))
        } catch {
            try? preserveCorruptPrimary()
            guard fileManager.fileExists(atPath: backupURL.path),
                  let backupData = try? Data(contentsOf: backupURL),
                  let recovered = try? decodeRecords(backupData) else {
                throw error
            }
            try? backupData.write(to: historyURL, options: [.atomic])
            return recovered
        }
    }

    private func writeRecords(_ records: [NetworkSpeedTestRecord]) throws {
        let data = try encoder.encode(NetworkSpeedHistoryArchive(records: records))
        _ = try decodeRecords(data)
        if fileManager.fileExists(atPath: historyURL.path),
           let currentData = try? Data(contentsOf: historyURL),
           (try? decodeRecords(currentData)) != nil {
            try currentData.write(to: backupURL, options: [.atomic])
        }
        try data.write(to: historyURL, options: [.atomic])
    }

    private func decodeRecords(_ data: Data) throws -> [NetworkSpeedTestRecord] {
        try decoder.decode(NetworkSpeedHistoryArchive.self, from: data)
            .records
            .sorted { $0.completedAt > $1.completedAt }
    }

    private func preserveCorruptPrimary() throws {
        try fileManager.createDirectory(
            at: corruptDirectoryURL,
            withIntermediateDirectories: true
        )
        let destination = corruptDirectoryURL.appendingPathComponent(
            "network-speed-history-corrupt-\(UUID().uuidString).json"
        )
        try fileManager.copyItem(at: historyURL, to: destination)
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}
