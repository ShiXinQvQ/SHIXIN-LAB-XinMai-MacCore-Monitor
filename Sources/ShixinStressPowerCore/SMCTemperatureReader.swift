import Foundation
import IOKit

struct SMCTemperatureSnapshot {
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
    var detail: String

    var hasAnyTemperature: Bool {
        cpuTemperatureC != nil || gpuTemperatureC != nil || socTemperatureC != nil
    }
}

enum SMCTemperatureReader {
    private static let cacheLock = NSLock()
    private static var cachedTemperatureKeys: [String]?
    private static var cachedClassifiedKeys: ClassifiedTemperatureKeys?

    private static let cpuKeys: [String] = unique([
        "TC0D", "TC0E", "TC0F", "TC0H", "TC0P", "TCAD",
        "Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0X", "Tp0b",
        "Tp1h", "Tp1t", "Tp1p", "Tp1l", "Tp0f", "Tp0j",
        "Te05", "Te0L", "Te0P", "Te0S", "Tf04", "Tf09", "Tf0A", "Tf0B", "Tf0D", "Tf0E",
        "Tf44", "Tf49", "Tf4A", "Tf4B", "Tf4D", "Tf4E",
        "Te09", "Te0H", "Tp0V", "Tp0Y", "Tp0e",
        "Tp00", "Tp04", "Tp08", "Tp0C", "Tp0G", "Tp0K", "Tp0O", "Tp0R", "Tp0U",
        "Tp0a", "Tp0d", "Tp0g", "Tp0m", "Tp0p", "Tp0u", "Tp0y"
    ])

    private static let gpuKeys: [String] = unique([
        "TCGC", "TG0D", "TGDD", "TG0H", "TG0P",
        "Tg05", "Tg0D", "Tg0L", "Tg0T",
        "Tg0f", "Tg0j",
        "Tf14", "Tf18", "Tf19", "Tf1A", "Tf24", "Tf28", "Tf29", "Tf2A",
        "Tg0G", "Tg0H", "Tg1U", "Tg1k", "Tg0K", "Tg0d", "Tg0e", "Tg0k",
        "Tg0U", "Tg0X", "Tg0g", "Tg1Y", "Tg1c", "Tg1g"
    ])

    private static let fanCurrentRPMKeys = unique([
        "F0Ac", "F1Ac", "F2Ac", "F3Ac"
    ])

    private struct ClassifiedTemperatureKeys {
        var family: AppleChipFamily
        var cpu: [String]
        var gpu: [String]
        var soc: [String]
        var ssd: [String]
        var wifi: [String]
        var airflow: [String]
        var ambient: [String]
    }

    static func read() -> SMCTemperatureSnapshot {
        guard let client = SMCReadClient() else {
            return SMCTemperatureSnapshot(
                cpuTemperatureC: nil,
                gpuTemperatureC: nil,
                socTemperatureC: nil,
                cpuSensorCount: 0,
                gpuSensorCount: 0,
                socSensorCount: 0,
                fanRPMs: [],
                ssdTemperatureC: nil,
                wifiTemperatureC: nil,
                airflowTemperatureC: nil,
                ambientTemperatureC: nil,
                detail: "AppleSMC 无法打开"
            )
        }

        let family = AppleChipFamily.current()
        let classified = classifiedTemperatureKeys(using: client, family: family)
        let cpuValues = readTemperatureValues(classified.cpu, using: client)
        let gpuValues = readTemperatureValues(classified.gpu, using: client)
        let socValues = readTemperatureValues(classified.soc, using: client)
        let ssdValues = readTemperatureValues(classified.ssd, using: client)
        let wifiValues = readTemperatureValues(classified.wifi, using: client)
        let airflowValues = readTemperatureValues(classified.airflow, using: client)
        let ambientValues = readTemperatureValues(classified.ambient, using: client)
        let fanRPMs = fanCurrentRPMKeys.compactMap { sanitizeFanRPM(client.readValue(forKey: $0)) }

        return SMCTemperatureSnapshot(
            cpuTemperatureC: cpuValues.values.max(),
            gpuTemperatureC: gpuValues.values.max(),
            socTemperatureC: socValues.values.max(),
            cpuSensorCount: cpuValues.count,
            gpuSensorCount: gpuValues.count,
            socSensorCount: socValues.count,
            fanRPMs: fanRPMs,
            ssdTemperatureC: ssdValues.values.max(),
            wifiTemperatureC: wifiValues.values.max(),
            airflowTemperatureC: Array(airflowValues.values).average(),
            ambientTemperatureC: Array(ambientValues.values).average(),
            detail: "AppleSMC \(family.title) 温度 key · CPU \(cpuValues.count) / GPU \(gpuValues.count) / SoC \(socValues.count)"
        )
    }

    static func debugSummary() -> String {
        guard let client = SMCReadClient() else {
            return "SMC open failed"
        }
        let keyCount = client.readValue(forKey: "#KEY").map { String(format: "%.0f", $0) } ?? "nil"
        let allKeys = client.allKeys()
        let sampleKeys = ["#KEY", "Te05", "Tf04", "Tf14", "Tg05", "TPD0", "TRD0"]
            .map { key in "\(key)=\(client.readValue(forKey: key).map { String(format: "%.2f", $0) } ?? "nil")" }
            .joined(separator: " ")
        let snapshot = read()
        return "SMC #KEY=\(keyCount) allKeys=\(allKeys.count) \(sampleKeys) cpu=\(snapshot.cpuSensorCount)/\(snapshot.cpuTemperatureC.map { String(format: "%.2f", $0) } ?? "nil") gpu=\(snapshot.gpuSensorCount)/\(snapshot.gpuTemperatureC.map { String(format: "%.2f", $0) } ?? "nil") soc=\(snapshot.socSensorCount)/\(snapshot.socTemperatureC.map { String(format: "%.2f", $0) } ?? "nil") fan=\(snapshot.fanRPMs.map { String(format: "%.0f", $0) }.joined(separator: ",")) ssd=\(snapshot.ssdTemperatureC.map { String(format: "%.2f", $0) } ?? "nil") wifi=\(snapshot.wifiTemperatureC.map { String(format: "%.2f", $0) } ?? "nil") airflow=\(snapshot.airflowTemperatureC.map { String(format: "%.2f", $0) } ?? "nil") detail=\(snapshot.detail)"
    }

    private static func sanitize(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 15, value < 125 else { return nil }
        return value
    }

    private static func sanitizeFanRPM(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0, value < 20_000 else { return nil }
        return value
    }

    private static func readTemperatureValues(_ keys: [String], using client: SMCReadClient) -> [String: Double] {
        var values: [String: Double] = [:]
        for key in keys {
            if let value = sanitize(client.readValue(forKey: key)) {
                values[key] = value
            }
        }
        return values
    }

    private static func temperatureKeys(using client: SMCReadClient) -> [String] {
        cacheLock.lock()
        if let cachedTemperatureKeys {
            cacheLock.unlock()
            return cachedTemperatureKeys
        }
        cacheLock.unlock()

        let keys = client.allKeys().filter { $0.hasPrefix("T") }

        cacheLock.lock()
        cachedTemperatureKeys = keys
        cacheLock.unlock()
        return keys
    }

    private static func classifiedTemperatureKeys(using client: SMCReadClient, family: AppleChipFamily) -> ClassifiedTemperatureKeys {
        cacheLock.lock()
        if let cachedClassifiedKeys, cachedClassifiedKeys.family == family {
            cacheLock.unlock()
            return cachedClassifiedKeys
        }
        cacheLock.unlock()

        let allKeys = temperatureKeys(using: client)
        var cpu = Set(cpuKeys(for: family))
        var gpu = Set(gpuKeys(for: family))
        var soc = Set<String>()
        var ssd = Set<String>()
        var wifi = Set<String>()
        var airflow = Set<String>()
        var ambient = Set<String>()

        for key in allKeys {
            if isEnumeratedCPUKey(key, family: family) {
                cpu.insert(key)
            } else if isEnumeratedGPUKey(key, family: family) {
                gpu.insert(key)
            } else if isEnumeratedSoCKey(key) {
                soc.insert(key)
            } else if isSSDTemperatureKey(key) {
                ssd.insert(key)
            } else if isWiFiTemperatureKey(key) {
                wifi.insert(key)
            } else if isAirflowTemperatureKey(key) {
                airflow.insert(key)
            } else if isAmbientTemperatureKey(key) {
                ambient.insert(key)
            }
        }

        let classified = ClassifiedTemperatureKeys(
            family: family,
            cpu: unique(Array(cpu)),
            gpu: unique(Array(gpu)),
            soc: unique(Array(soc)),
            ssd: unique(Array(ssd)),
            wifi: unique(Array(wifi)),
            airflow: unique(Array(airflow)),
            ambient: unique(Array(ambient))
        )

        cacheLock.lock()
        cachedClassifiedKeys = classified
        cacheLock.unlock()
        return classified
    }

    private static func cpuKeys(for family: AppleChipFamily) -> [String] {
        let intel = ["TC0D", "TC0E", "TC0F", "TC0H", "TC0P", "TCAD"]
        switch family {
        case .m1:
            return intel + ["Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0X", "Tp0b"]
        case .m2:
            return intel + ["Tp1h", "Tp1t", "Tp1p", "Tp1l", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0X", "Tp0b", "Tp0f", "Tp0j"]
        case .m3:
            return intel + [
                "Te05", "Te0L", "Te0P", "Te0S",
                "Tf04", "Tf09", "Tf0A", "Tf0B", "Tf0D", "Tf0E",
                "Tf44", "Tf49", "Tf4A", "Tf4B", "Tf4D", "Tf4E"
            ]
        case .m4:
            return intel + ["Te05", "Te09", "Te0H", "Te0S", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0V", "Tp0Y", "Tp0b", "Tp0e"]
        case .m5:
            return intel + ["Tp00", "Tp04", "Tp08", "Tp0C", "Tp0G", "Tp0K", "Tp0O", "Tp0R", "Tp0U", "Tp0X", "Tp0a", "Tp0d", "Tp0g", "Tp0j", "Tp0m", "Tp0p", "Tp0u", "Tp0y"]
        case .unknown:
            return cpuKeys
        }
    }

    private static func gpuKeys(for family: AppleChipFamily) -> [String] {
        let intel = ["TCGC", "TG0D", "TGDD", "TG0H", "TG0P"]
        switch family {
        case .m1:
            return intel + ["Tg05", "Tg0D", "Tg0L", "Tg0T"]
        case .m2:
            return intel + ["Tg0f", "Tg0j"]
        case .m3:
            return intel + ["Tf14", "Tf18", "Tf19", "Tf1A", "Tf24", "Tf28", "Tf29", "Tf2A"]
        case .m4:
            return intel + ["Tg0G", "Tg0H", "Tg1U", "Tg1k", "Tg0K", "Tg0L", "Tg0d", "Tg0e", "Tg0j", "Tg0k"]
        case .m5:
            return intel + ["Tg0U", "Tg0X", "Tg0d", "Tg0g", "Tg0j", "Tg1Y", "Tg1c", "Tg1g"]
        case .unknown:
            return gpuKeys
        }
    }

    private static func isEnumeratedCPUKey(_ key: String, family: AppleChipFamily) -> Bool {
        guard family == .m3 else { return false }
        if key.hasPrefix("Te") {
            return true
        }
        let m3PerformanceCPUKeys: Set<String> = [
            "Tf04", "Tf09", "Tf0A", "Tf0B", "Tf0D", "Tf0E",
            "Tf44", "Tf49", "Tf4A", "Tf4B", "Tf4D", "Tf4E"
        ]
        if m3PerformanceCPUKeys.contains(key) {
            return true
        }
        return false
    }

    private static func isEnumeratedGPUKey(_ key: String, family: AppleChipFamily) -> Bool {
        if key.hasPrefix("Tg") {
            return true
        }
        guard family == .m3 else {
            return false
        }
        let m3GPUKeys: Set<String> = [
            "Tf14", "Tf18", "Tf19", "Tf1A",
            "Tf24", "Tf28", "Tf29", "Tf2A",
            "Tf34", "Tf38", "Tf39", "Tf3A"
        ]
        if m3GPUKeys.contains(key) {
            return true
        }
        if key.hasPrefix("TG") {
            return true
        }
        return false
    }

    private static func isEnumeratedSoCKey(_ key: String) -> Bool {
        key.hasPrefix("TPD")
            || key.hasPrefix("TRD")
            || key == "TPDX"
            || key == "TRDX"
            || key == "TCDX"
            || key == "TCMb"
            || key == "TCMz"
    }

    private static func isSSDTemperatureKey(_ key: String) -> Bool {
        key.hasPrefix("TN")
            || key.hasPrefix("TH")
            || key.hasPrefix("Ts")
            || key.hasPrefix("TS")
    }

    private static func isWiFiTemperatureKey(_ key: String) -> Bool {
        key.hasPrefix("TW")
            || key.hasPrefix("TI")
    }

    private static func isAirflowTemperatureKey(_ key: String) -> Bool {
        key.hasPrefix("Ta")
            || key.hasPrefix("TA")
    }

    private static func isAmbientTemperatureKey(_ key: String) -> Bool {
        key.hasPrefix("TB")
            || key.hasPrefix("Tm")
    }

    private static func unique(_ keys: [String]) -> [String] {
        var seen = Set<String>()
        return keys.filter { seen.insert($0).inserted }
    }
}

private enum AppleChipFamily: Equatable {
    case m1
    case m2
    case m3
    case m4
    case m5
    case unknown

    var title: String {
        switch self {
        case .m1: "M1"
        case .m2: "M2"
        case .m3: "M3"
        case .m4: "M4"
        case .m5: "M5"
        case .unknown: "Apple Silicon"
        }
    }

    static func current() -> AppleChipFamily {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else {
            return .unknown
        }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0) == 0 else {
            return .unknown
        }
        let brand = String(cString: buffer).lowercased()
        if brand.contains("m5") { return .m5 }
        if brand.contains("m4") { return .m4 }
        if brand.contains("m3") { return .m3 }
        if brand.contains("m2") { return .m2 }
        if brand.contains("m1") { return .m1 }
        return .unknown
    }
}

private final class SMCReadClient {
    private enum Command: UInt8 {
        case kernelIndex = 2
        case readBytes = 5
        case readIndex = 8
        case readKeyInfo = 9
    }

    private typealias SMCBytes = (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )

    private struct SMCVersion {
        var major: CUnsignedChar = 0
        var minor: CUnsignedChar = 0
        var build: CUnsignedChar = 0
        var reserved: CUnsignedChar = 0
        var release: CUnsignedShort = 0
    }

    private struct SMCLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    private struct SMCKeyInfo {
        var dataSize: IOByteCount32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    private struct SMCKeyData {
        var key: UInt32 = 0
        var version = SMCVersion()
        var pLimitData = SMCLimitData()
        var keyInfo = SMCKeyInfo()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: SMCBytes = (
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0
        )
    }

    private struct SMCValueBuffer {
        var key: String
        var dataSize: UInt32 = 0
        var dataType: String = ""
        var bytes: [UInt8] = Array(repeating: 0, count: 32)
    }

    private var connection: io_connect_t = 0

    init?() {
        var iterator: io_iterator_t = 0
        let match = IOServiceMatching("AppleSMC")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == kIOReturnSuccess else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        let device = IOIteratorNext(iterator)
        guard device != 0 else { return nil }
        defer { IOObjectRelease(device) }

        guard IOServiceOpen(device, mach_task_self_, 0, &connection) == kIOReturnSuccess else {
            return nil
        }
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    func readValue(forKey key: String) -> Double? {
        var value = SMCValueBuffer(key: key)
        guard read(&value) == kIOReturnSuccess,
              value.dataSize > 0 else {
            return nil
        }

        switch value.dataType {
        case "ui8 ":
            return Double(value.bytes[safe: 0] ?? 0)
        case "ui16":
            return unsigned16(value.bytes).map(Double.init)
        case "ui32":
            return unsigned32(value.bytes).map(Double.init)
        case "sp1e":
            return fixedPoint(value.bytes, divisor: 16_384)
        case "sp3c":
            return fixedPoint(value.bytes, divisor: 4_096)
        case "sp4b":
            return fixedPoint(value.bytes, divisor: 2_048)
        case "sp5a":
            return fixedPoint(value.bytes, divisor: 1_024)
        case "sp69":
            return fixedPoint(value.bytes, divisor: 512)
        case "sp78":
            return fixedPoint(value.bytes, divisor: 256)
        case "sp87":
            return fixedPoint(value.bytes, divisor: 128)
        case "sp96":
            return fixedPoint(value.bytes, divisor: 64)
        case "spa5":
            return fixedPoint(value.bytes, divisor: 32)
        case "spb4":
            return fixedPoint(value.bytes, divisor: 16)
        case "spf0":
            return fixedPoint(value.bytes, divisor: 1)
        case "flt ":
            return float32(value.bytes).map(Double.init)
        case "fpe2":
            guard value.bytes.count >= 2 else { return nil }
            return Double((Int(value.bytes[0]) << 6) + (Int(value.bytes[1]) >> 2))
        default:
            return nil
        }
    }

    func allKeys() -> [String] {
        guard let count = readValue(forKey: "#KEY"), count > 0 else {
            return []
        }

        var results: [String] = []
        for index in 0..<Int(count) {
            var input = SMCKeyData()
            var output = SMCKeyData()
            input.data8 = Command.readIndex.rawValue
            input.data32 = UInt32(index)
            guard call(index: Command.kernelIndex.rawValue, input: &input, output: &output) == kIOReturnSuccess else {
                continue
            }
            let key = stringCode(output.key)
            if key.count == 4 {
                results.append(key)
            }
        }
        return results
    }

    private func read(_ value: inout SMCValueBuffer) -> kern_return_t {
        guard value.key.utf8.count == 4 else { return kIOReturnBadArgument }
        var input = SMCKeyData()
        var output = SMCKeyData()

        input.key = keyCode(value.key)
        input.data8 = Command.readKeyInfo.rawValue

        var result = call(index: Command.kernelIndex.rawValue, input: &input, output: &output)
        guard result == kIOReturnSuccess else {
            return result
        }

        value.dataSize = UInt32(output.keyInfo.dataSize)
        value.dataType = stringCode(output.keyInfo.dataType)
        input.keyInfo.dataSize = output.keyInfo.dataSize
        input.data8 = Command.readBytes.rawValue

        result = call(index: Command.kernelIndex.rawValue, input: &input, output: &output)
        guard result == kIOReturnSuccess else {
            return result
        }

        let bytes = bytesArray(output.bytes, count: min(Int(value.dataSize), value.bytes.count))
        for index in bytes.indices {
            value.bytes[index] = bytes[index]
        }
        return kIOReturnSuccess
    }

    private func call(index: UInt8, input: inout SMCKeyData, output: inout SMCKeyData) -> kern_return_t {
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride
        return IOConnectCallStructMethod(connection, UInt32(index), &input, inputSize, &output, &outputSize)
    }

    private func keyCode(_ key: String) -> UInt32 {
        key.utf8.reduce(UInt32(0)) { result, byte in
            (result << 8) | UInt32(byte)
        }
    }

    private func stringCode(_ code: UInt32) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }

    private func bytesArray(_ tuple: SMCBytes, count: Int) -> [UInt8] {
        var mutable = tuple
        return withUnsafeBytes(of: &mutable) { rawBuffer in
            Array(rawBuffer.prefix(max(0, min(count, rawBuffer.count))))
        }
    }

    private func unsigned16(_ bytes: [UInt8]) -> UInt16? {
        guard bytes.count >= 2 else { return nil }
        return (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
    }

    private func unsigned32(_ bytes: [UInt8]) -> UInt32? {
        guard bytes.count >= 4 else { return nil }
        return (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
    }

    private func fixedPoint(_ bytes: [UInt8], divisor: Double) -> Double? {
        guard let raw = unsigned16(bytes) else { return nil }
        return Double(raw) / divisor
    }

    private func float32(_ bytes: [UInt8]) -> Float? {
        guard bytes.count >= 4 else { return nil }
        var value = Float(0)
        withUnsafeMutableBytes(of: &value) { destination in
            destination.copyBytes(from: bytes.prefix(4))
        }
        return value
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
