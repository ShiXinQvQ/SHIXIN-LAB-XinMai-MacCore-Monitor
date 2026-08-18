import Darwin
import Foundation

public enum ReleaseConstants {
    public static let appVersion = "0.3.0-beta"
    public static let appBuild = "300"
}

public enum HelperConstants {
    public static let label = "com.shixinqvq.shixinlab.macstresspower.helper"
    public static let installedHelperPath = "/Library/PrivilegedHelperTools/\(label)"
    public static let launchDaemonPath = "/Library/LaunchDaemons/\(label).plist"
    public static let socketPath = "/var/run/\(label).sock"
    public static let bundledHelperRelativePath = "PrivilegedHelperTools/\(label)"
    public static let helperVersion = "0.3.0-helper"

    public static var launchDaemonPlist: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(installedHelperPath)</string>
                <string>--serve</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>/Library/Logs/\(label).out.log</string>
            <key>StandardErrorPath</key>
            <string>/Library/Logs/\(label).err.log</string>
        </dict>
        </plist>
        """
    }
}

public struct HelperResponse: Codable {
    public var ok: Bool
    public var helperVersion: String
    public var euid: UInt32
    public var sample: TelemetrySample?
    public var error: String?
    public var samplingHealth: HelperSamplingHealth?

    public init(
        ok: Bool,
        helperVersion: String,
        euid: UInt32,
        sample: TelemetrySample?,
        error: String?,
        samplingHealth: HelperSamplingHealth? = nil
    ) {
        self.ok = ok
        self.helperVersion = helperVersion
        self.euid = euid
        self.sample = sample
        self.error = error
        self.samplingHealth = samplingHealth
    }
}

public enum HelperSocketClient {
    public static func sample() throws -> TelemetrySample {
        let data = try request("sample\n")
        let decoder = JSONDecoder.helperDecoder
        let response = try decoder.decode(HelperResponse.self, from: data)
        guard var sample = response.sample else {
            throw HelperSocketError.helperReturnedError(response.error ?? "helper 没有返回 sample")
        }
        if !response.ok {
            sample.isDegraded = true
            appendMessage(response.error ?? "Helper 返回降级样本", to: &sample)
        }
        if let health = response.samplingHealth {
            sample.helperSampleSequence = health.sequence
            sample.helperSampleAgeSeconds = health.sampleAgeSeconds
            sample.samplingIntervalMilliseconds = health.intervalMilliseconds
        }
        sample.sourceDetail = "LaunchDaemon helper \(response.helperVersion) / \(sample.sourceDetail)"
        if response.helperVersion != HelperConstants.helperVersion {
            mergeLocalTemperatures(into: &sample)
            appendMessage(
                "Helper 需要更新：当前 \(response.helperVersion)，需要 \(HelperConstants.helperVersion)。旧版 helper 提供 powermetrics 功耗；温度、风扇与扩展传感器已由 App 本地 AppleSMC/HID 新版读取链路补齐。",
                to: &sample
            )
        }
        return sample
    }

    public static func ping() -> Bool {
        (try? info()) != nil
    }

    public static func info() throws -> HelperResponse {
        let data = try request("ping\n")
        return try JSONDecoder.helperDecoder.decode(HelperResponse.self, from: data)
    }

    private static func request(_ request: String) throws -> Data {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw HelperSocketError.socketFailed(errnoDescription())
        }
        defer { close(fd) }
        configureSocket(fd, receiveTimeout: 2, sendTimeout: 2)

        try withSockaddr(path: HelperConstants.socketPath) { pointer, length in
            guard connect(fd, pointer, length) == 0 else {
                throw HelperSocketError.connectFailed(errnoDescription())
            }
        }

        try writeAll(Data(request.utf8), to: fd)
        let result = try readAll(from: fd, maximumBytes: 1024 * 1024)

        guard !result.isEmpty else {
            throw HelperSocketError.readFailed("helper 返回空响应")
        }
        return result
    }

    private static func mergeLocalTemperatures(into sample: inout TelemetrySample) {
        let temperatures = HIDTemperatureReader.read()
        if let cpuTemperature = temperatures.cpuTemperatureC {
            sample.cpuTemperatureC = cpuTemperature
        }
        if let gpuTemperature = temperatures.gpuTemperatureC {
            sample.gpuTemperatureC = gpuTemperature
        }
        if let socTemperature = temperatures.socTemperatureC {
            sample.socTemperatureC = socTemperature
        }
        if temperatures.hasAnyTemperature {
            sample.temperatureSourceDetail = "\(temperatures.sourceDetail) · App 本地补齐"
            sample.cpuTemperatureSensorCount = temperatures.cpuSensorCount
            sample.gpuTemperatureSensorCount = temperatures.gpuSensorCount
            sample.socTemperatureSensorCount = temperatures.socSensorCount
        }
        sample.fanRPMs = temperatures.fanRPMs
        sample.ssdTemperatureC = temperatures.ssdTemperatureC
        let storageTemperature = StorageTemperatureReader.read()
        sample.diskTemperatureC = storageTemperature.diskTemperatureC
        sample.diskTemperatureSourceDetail = storageTemperature.sourceDetail
        sample.wifiTemperatureC = temperatures.wifiTemperatureC
        sample.airflowTemperatureC = temperatures.airflowTemperatureC
        sample.ambientTemperatureC = temperatures.ambientTemperatureC
    }

    private static func appendMessage(_ message: String, to sample: inout TelemetrySample) {
        if let existing = sample.message, !existing.isEmpty {
            sample.message = "\(existing)\n\(message)"
        } else {
            sample.message = message
        }
    }
}

public final class HelperSocketServer: @unchecked Sendable {
    private let sampleService = HelperSampleService()
    private let requestLimiter = HelperRequestLimiter()
    private let lifecycleLock = NSLock()
    private let clientSlots = DispatchSemaphore(value: 8)
    private let clientQueue = DispatchQueue(
        label: "com.shixinqvq.shixinlab.macstresspower.helper.clients",
        qos: .utility,
        attributes: .concurrent
    )
    private var stopping = false

    public init() {}

    public func stop() {
        lifecycleLock.lock()
        guard !stopping else {
            lifecycleLock.unlock()
            return
        }
        stopping = true
        lifecycleLock.unlock()

        // Wake the blocking accept call. The run loop owns and closes the listening fd.
        let wakeSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard wakeSocket >= 0 else { return }
        defer { close(wakeSocket) }
        try? withSockaddr(path: HelperConstants.socketPath) { pointer, length in
            _ = connect(wakeSocket, pointer, length)
        }
    }

    public func run() throws {
        signal(SIGPIPE, SIG_IGN)
        sampleService.start()
        unlink(HelperConstants.socketPath)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw HelperSocketError.socketFailed(errnoDescription())
        }
        defer {
            sampleService.stop()
            close(fd)
            unlink(HelperConstants.socketPath)
        }

        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        try withSockaddr(path: HelperConstants.socketPath) { pointer, length in
            guard bind(fd, pointer, length) == 0 else {
                throw HelperSocketError.bindFailed(errnoDescription())
            }
        }

        guard chmod(HelperConstants.socketPath, 0o666) == 0 else {
            throw HelperSocketError.bindFailed("无法设置 socket 权限：\(errnoDescription())")
        }
        guard listen(fd, 16) == 0 else {
            throw HelperSocketError.listenFailed(errnoDescription())
        }

        var acceptRetryDelay: TimeInterval = 0.05
        while !isStopping {
            let client = accept(fd, nil, nil)
            if client < 0 {
                if isStopping { break }
                if errno == EINTR { continue }
                if errno == EMFILE || errno == ENFILE {
                    Thread.sleep(forTimeInterval: acceptRetryDelay)
                    acceptRetryDelay = min(1, acceptRetryDelay * 2)
                    continue
                }
                throw HelperSocketError.acceptFailed(errnoDescription())
            }
            if isStopping {
                close(client)
                break
            }
            acceptRetryDelay = 0.05
            configureSocket(client, receiveTimeout: 1, sendTimeout: 2)

            guard clientSlots.wait(timeout: .now()) == .success else {
                sendBusyResponse(to: client)
                close(client)
                continue
            }
            clientQueue.async { [self] in
                defer {
                    close(client)
                    clientSlots.signal()
                }
                handle(client: client)
            }
        }
    }

    private var isStopping: Bool {
        lifecycleLock.lock()
        let value = stopping
        lifecycleLock.unlock()
        return value
    }

    private func handle(client: Int32) {
        let peerUID = peerUserID(client)
        let response: HelperResponse
        do {
            let command = try readCommand(from: client)
            switch command {
            case "ping":
                response = HelperResponse(
                    ok: true,
                    helperVersion: HelperConstants.helperVersion,
                    euid: geteuid(),
                    sample: nil,
                    error: nil,
                    samplingHealth: sampleService.health()
                )
            case "sample":
                guard requestLimiter.allowSampleRequest(userID: peerUID) else {
                    send(
                        HelperResponse(
                            ok: false,
                            helperVersion: HelperConstants.helperVersion,
                            euid: geteuid(),
                            sample: nil,
                            error: "本机客户端采样请求过于频繁，请稍后重试。",
                            samplingHealth: sampleService.health()
                        ),
                        to: client
                    )
                    return
                }
                let snapshot = sampleService.currentSnapshot()
                let sample = snapshot.sample
                response = HelperResponse(
                    ok: true,
                    helperVersion: HelperConstants.helperVersion,
                    euid: geteuid(),
                    sample: sample,
                    error: sample.isDegraded ? sample.message : nil,
                    samplingHealth: snapshot.health
                )
            default:
                response = HelperResponse(
                    ok: false,
                    helperVersion: HelperConstants.helperVersion,
                    euid: geteuid(),
                    sample: nil,
                    error: "不支持的 Helper 命令。",
                    samplingHealth: sampleService.health()
                )
            }
        } catch {
            response = HelperResponse(
                ok: false,
                helperVersion: HelperConstants.helperVersion,
                euid: geteuid(),
                sample: nil,
                error: error.localizedDescription,
                samplingHealth: sampleService.health()
            )
        }
        send(response, to: client)
    }

    private func send(_ response: HelperResponse, to client: Int32) {
        do {
            try writeAll(JSONEncoder.helperEncoder.encode(response), to: client)
        } catch {
            let fallback = HelperResponse(
                ok: false,
                helperVersion: HelperConstants.helperVersion,
                euid: geteuid(),
                sample: nil,
                error: "Helper 响应编码或写入失败。"
            )
            if let data = try? JSONEncoder.helperEncoder.encode(fallback) {
                try? writeAll(data, to: client)
            }
        }
    }

    private func sendBusyResponse(to client: Int32) {
        send(
            HelperResponse(
                ok: false,
                helperVersion: HelperConstants.helperVersion,
                euid: geteuid(),
                sample: nil,
                error: "Helper 当前连接较多，请稍后重试。",
                samplingHealth: sampleService.health()
            ),
            to: client
        )
    }

    private func readCommand(from fd: Int32) throws -> String {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 128)
        while data.count < 512 {
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count > 0 {
                data.append(buffer, count: count)
                if data.contains(10) { break }
            } else if count == 0 {
                break
            } else if errno == EINTR {
                continue
            } else {
                throw HelperSocketError.readFailed(errnoDescription())
            }
        }
        guard !data.isEmpty else {
            throw HelperSocketError.readFailed("Helper 请求为空")
        }
        guard data.count < 512 else {
            throw HelperSocketError.readFailed("Helper 请求超过长度限制")
        }
        return String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func peerUserID(_ fd: Int32) -> uid_t {
        var userID: uid_t = 0
        var groupID: gid_t = 0
        guard getpeereid(fd, &userID, &groupID) == 0 else { return 0 }
        return userID
    }
}

private final class HelperRequestLimiter: @unchecked Sendable {
    private let lock = NSLock()
    private var requestTimes: [uid_t: [TimeInterval]] = [:]

    func allowSampleRequest(userID: uid_t) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock()
        defer { lock.unlock() }
        var recent = requestTimes[userID, default: []].filter { now - $0 < 2 }
        guard recent.count < 10 else {
            requestTimes[userID] = recent
            return false
        }
        recent.append(now)
        requestTimes[userID] = recent
        return true
    }
}

public enum HelperSocketError: LocalizedError {
    case socketFailed(String)
    case connectFailed(String)
    case bindFailed(String)
    case listenFailed(String)
    case acceptFailed(String)
    case writeFailed(String)
    case readFailed(String)
    case helperReturnedError(String)
    case pathTooLong(String)

    public var errorDescription: String? {
        switch self {
        case .socketFailed(let message): "创建本地 socket 失败：\(message)"
        case .connectFailed(let message): "连接 Helper 失败：\(message)"
        case .bindFailed(let message): "Helper 绑定 socket 失败：\(message)"
        case .listenFailed(let message): "Helper 监听 socket 失败：\(message)"
        case .acceptFailed(let message): "Helper 接收连接失败：\(message)"
        case .writeFailed(let message): "写入 Helper 请求失败：\(message)"
        case .readFailed(let message): "读取 Helper 响应失败：\(message)"
        case .helperReturnedError(let message): "Helper 返回错误：\(message)"
        case .pathTooLong(let path): "Unix socket 路径过长：\(path)"
        }
    }
}

extension JSONEncoder {
    public static var helperEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(HelperWireDateCodec.string(from: date))
        }
        return encoder
    }
}

extension JSONDecoder {
    public static var helperDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            guard let date = HelperWireDateCodec.date(from: rawValue) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid Helper ISO 8601 date: \(rawValue)"
                )
            }
            return date
        }
        return decoder
    }
}

private enum HelperWireDateCodec {
    static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    static func date(from rawValue: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: rawValue) {
            return date
        }

        let legacyFormatter = ISO8601DateFormatter()
        legacyFormatter.formatOptions = [.withInternetDateTime]
        return legacyFormatter.date(from: rawValue)
    }
}

private func errnoDescription() -> String {
    String(cString: strerror(errno))
}

private func configureSocket(_ fd: Int32, receiveTimeout: TimeInterval, sendTimeout: TimeInterval) {
    var noSigPipe: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

    var receive = timeval(
        tv_sec: Int(receiveTimeout),
        tv_usec: Int32((receiveTimeout.truncatingRemainder(dividingBy: 1) * 1_000_000).rounded())
    )
    var send = timeval(
        tv_sec: Int(sendTimeout),
        tv_usec: Int32((sendTimeout.truncatingRemainder(dividingBy: 1) * 1_000_000).rounded())
    )
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &receive, socklen_t(MemoryLayout<timeval>.size))
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &send, socklen_t(MemoryLayout<timeval>.size))
}

private func writeAll(_ data: Data, to fd: Int32) throws {
    try data.withUnsafeBytes { rawBuffer in
        guard let base = rawBuffer.baseAddress else { return }
        var offset = 0
        while offset < rawBuffer.count {
            let count = Darwin.write(fd, base.advanced(by: offset), rawBuffer.count - offset)
            if count > 0 {
                offset += count
            } else if count < 0, errno == EINTR {
                continue
            } else {
                throw HelperSocketError.writeFailed(errnoDescription())
            }
        }
    }
}

private func readAll(from fd: Int32, maximumBytes: Int) throws -> Data {
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 16 * 1024)
    while true {
        let count = Darwin.read(fd, &buffer, buffer.count)
        if count > 0 {
            guard result.count + count <= maximumBytes else {
                throw HelperSocketError.readFailed("Helper 响应超过大小限制")
            }
            result.append(buffer, count: count)
        } else if count == 0 {
            break
        } else if errno == EINTR {
            continue
        } else {
            throw HelperSocketError.readFailed(errnoDescription())
        }
    }
    return result
}

private func withSockaddr<T>(path: String, _ body: (UnsafePointer<sockaddr>, socklen_t) throws -> T) throws -> T {
    let bytes = Array(path.utf8)
    guard bytes.count < MemoryLayout.size(ofValue: sockaddr_un().sun_path) else {
        throw HelperSocketError.pathTooLong(path)
    }

    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutableBytes(of: &address.sun_path) { rawBuffer in
        for index in 0..<bytes.count {
            rawBuffer[index] = bytes[index]
        }
        rawBuffer[bytes.count] = 0
    }

    let length = socklen_t(MemoryLayout<sa_family_t>.size + bytes.count + 1)
    return try withUnsafePointer(to: &address) { pointer in
        try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
            try body(sockaddrPointer, length)
        }
    }
}
