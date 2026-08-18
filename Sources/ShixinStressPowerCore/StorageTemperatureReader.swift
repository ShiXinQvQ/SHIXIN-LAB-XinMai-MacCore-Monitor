import Darwin
import Foundation

public struct StorageTemperatureSnapshot: Codable, Equatable {
    public var diskTemperatureC: Double?
    public var diskIdentifier: String?
    public var sourceDetail: String?

    public init(diskTemperatureC: Double?, diskIdentifier: String?, sourceDetail: String?) {
        self.diskTemperatureC = diskTemperatureC
        self.diskIdentifier = diskIdentifier
        self.sourceDetail = sourceDetail
    }

    public static let unavailable = StorageTemperatureSnapshot(
        diskTemperatureC: nil,
        diskIdentifier: nil,
        sourceDetail: "未读取到系统硬盘 SMART 温度"
    )
}

public enum StorageTemperatureReader {
    private static let cacheLock = NSLock()
    private static var cached: (date: Date, snapshot: StorageTemperatureSnapshot)?
    private static let cacheLifetime: TimeInterval = 5

    public static func read() -> StorageTemperatureSnapshot {
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

    private static func readUncached() -> StorageTemperatureSnapshot {
        let diskIdentifier = bootPhysicalDiskIdentifier()
        if let diskIdentifier,
           let smartctl = locateSmartctl(),
           let snapshot = readSmartctlTemperature(smartctl: smartctl, diskIdentifier: diskIdentifier) {
            return snapshot
        }

        if let snapshot = readDiskutilSmartTemperature(diskIdentifier: diskIdentifier) {
            return snapshot
        }

        return StorageTemperatureSnapshot(
            diskTemperatureC: nil,
            diskIdentifier: diskIdentifier,
            sourceDetail: "未读取到系统硬盘 SMART 温度"
        )
    }

    private static func bootPhysicalDiskIdentifier() -> String? {
        guard let data = run("/usr/sbin/diskutil", arguments: ["info", "-plist", "/"]) else { return nil }
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = plist as? [String: Any] else {
            return nil
        }

        if let stores = dictionary["APFSPhysicalStores"] as? [[String: Any]] {
            for store in stores {
                if let identifier = store["APFSPhysicalStore"] as? String,
                   let wholeDisk = wholeDiskIdentifier(from: identifier) {
                    return wholeDisk
                }
            }
        }

        if let parent = dictionary["ParentWholeDisk"] as? String,
           parent.hasPrefix("disk") {
            return parent
        }

        return nil
    }

    private static func readSmartctlTemperature(smartctl: String, diskIdentifier: String) -> StorageTemperatureSnapshot? {
        guard let data = run(smartctl, arguments: ["-a", "-j", "/dev/\(diskIdentifier)"]),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let current = nestedDouble(json, path: ["temperature", "current"])
            ?? nestedDouble(json, path: ["nvme_smart_health_information_log", "temperature"])
        guard let current, isPlausibleCelsius(current) else { return nil }

        return StorageTemperatureSnapshot(
            diskTemperatureC: current,
            diskIdentifier: diskIdentifier,
            sourceDetail: "smartctl /dev/\(diskIdentifier) SMART"
        )
    }

    private static func readDiskutilSmartTemperature(diskIdentifier: String?) -> StorageTemperatureSnapshot? {
        let targets = [diskIdentifier, nil].compactMap { $0 }
        for target in targets {
            if let snapshot = readDiskutilSmartTemperature(argument: "/dev/\(target)", diskIdentifier: target) {
                return snapshot
            }
        }
        return readDiskutilSmartTemperature(argument: "/", diskIdentifier: diskIdentifier)
    }

    private static func readDiskutilSmartTemperature(argument: String, diskIdentifier: String?) -> StorageTemperatureSnapshot? {
        guard let data = run("/usr/sbin/diskutil", arguments: ["info", "-plist", argument]),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = plist as? [String: Any],
              let smart = dictionary["SMARTDeviceSpecificKeysMayVaryNotGuaranteed"] as? [String: Any],
              let rawTemperature = numericValue(smart["TEMPERATURE"]) else {
            return nil
        }

        let celsius = rawTemperature > 200 ? rawTemperature - 273.15 : rawTemperature
        guard isPlausibleCelsius(celsius) else { return nil }

        let resolvedDisk = diskIdentifier ?? (dictionary["ParentWholeDisk"] as? String)
        return StorageTemperatureSnapshot(
            diskTemperatureC: celsius,
            diskIdentifier: resolvedDisk,
            sourceDetail: "diskutil SMART"
        )
    }

    private static func locateSmartctl() -> String? {
        let bundleCandidate = Bundle.main.resourceURL?
            .appendingPathComponent("Tools", isDirectory: true)
            .appendingPathComponent("smartctl")
            .path

        let candidates = [
            bundleCandidate,
            "/usr/local/sbin/smartctl",
            "/opt/homebrew/bin/smartctl",
            "/usr/local/bin/smartctl",
            "/opt/homebrew/sbin/smartctl"
        ].compactMap { $0 }

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func run(_ executable: String, arguments: [String]) -> Data? {
        guard FileManager.default.isExecutableFile(atPath: executable) else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
            let deadline = Date().addingTimeInterval(2)
            while process.isRunning, Date() < deadline {
                Thread.sleep(forTimeInterval: 0.02)
            }
            if process.isRunning {
                process.terminate()
                let terminationDeadline = Date().addingTimeInterval(0.25)
                while process.isRunning, Date() < terminationDeadline {
                    Thread.sleep(forTimeInterval: 0.02)
                }
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }
                return nil
            }
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            return data.isEmpty ? nil : data
        } catch {
            return nil
        }
    }

    private static func wholeDiskIdentifier(from identifier: String) -> String? {
        if let range = identifier.range(of: #"s\d+$"#, options: .regularExpression) {
            return String(identifier[..<range.lowerBound])
        }
        return identifier.hasPrefix("disk") ? identifier : nil
    }

    private static func nestedDouble(_ dictionary: [String: Any], path: [String]) -> Double? {
        var current: Any? = dictionary
        for key in path {
            current = (current as? [String: Any])?[key]
        }
        return numericValue(current)
    }

    private static func numericValue(_ value: Any?) -> Double? {
        switch value {
        case let value as Double:
            return value
        case let value as Int:
            return Double(value)
        case let value as NSNumber:
            return value.doubleValue
        case let value as String:
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    private static func isPlausibleCelsius(_ value: Double) -> Bool {
        value.isFinite && value >= 0 && value < 130
    }
}
