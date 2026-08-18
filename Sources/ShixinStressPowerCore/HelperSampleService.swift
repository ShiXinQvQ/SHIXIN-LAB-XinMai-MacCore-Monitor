import Darwin
import Foundation

public struct HelperSamplingHealth: Codable, Equatable {
    public var state: String
    public var sequence: UInt64
    public var sampleAgeSeconds: Double?
    public var intervalMilliseconds: Int
    public var lastError: String?

    public init(
        state: String,
        sequence: UInt64,
        sampleAgeSeconds: Double?,
        intervalMilliseconds: Int,
        lastError: String?
    ) {
        self.state = state
        self.sequence = sequence
        self.sampleAgeSeconds = sampleAgeSeconds
        self.intervalMilliseconds = intervalMilliseconds
        self.lastError = lastError
    }
}

final class HelperSampleService: @unchecked Sendable {
    static let intervalMilliseconds = 500
    private static let idleTimeout: TimeInterval = 5

    private let stateLock = NSLock()
    private let demandCondition = NSCondition()
    private let processTerminationLock = NSLock()
    private let streamQueue = DispatchQueue(label: "com.shixinqvq.shixinlab.macstresspower.helper.powermetrics", qos: .utility)
    private let sensorQueue = DispatchQueue(label: "com.shixinqvq.shixinlab.macstresspower.helper.sensors", qos: .utility)

    private var started = false
    private var stopped = false
    private var process: Process?
    private var latestSample: TelemetrySample?
    private var latestSampleUptime: TimeInterval?
    private var lastStoredCapturedAt: Date?
    private var sequence: UInt64 = 0
    private var samplingState = "idle"
    private var lastError: String?
    private var lastDemandUptime: TimeInterval?
    private var temperatures: HIDTemperatureSnapshot?
    private var storage = StorageTemperatureSnapshot.unavailable
    private var powerSource = PowerSourceSnapshot.unknown

    func start() {
        stateLock.lock()
        guard !started else {
            stateLock.unlock()
            return
        }
        started = true
        stateLock.unlock()

        sensorQueue.async { [weak self] in
            self?.runSensorLoop()
        }
        streamQueue.async { [weak self] in
            self?.runPowermetricsLoop()
        }
    }

    func stop() {
        demandCondition.lock()
        stateLock.lock()
        stopped = true
        let process = process
        stateLock.unlock()
        demandCondition.broadcast()
        demandCondition.unlock()
        terminate(process)
    }

    func health() -> HelperSamplingHealth {
        stateLock.lock()
        let state = samplingState
        let sequence = sequence
        let sampleUptime = latestSampleUptime
        let error = lastError
        stateLock.unlock()

        return HelperSamplingHealth(
            state: state,
            sequence: sequence,
            sampleAgeSeconds: sampleUptime.map { max(0, systemUptime - $0) },
            intervalMilliseconds: Self.intervalMilliseconds,
            lastError: error
        )
    }

    func currentSnapshot() -> (sample: TelemetrySample, health: HelperSamplingHealth) {
        markDemand()
        stateLock.lock()
        let baseSample = latestSample
        let sampleUptime = latestSampleUptime
        let sequence = sequence
        let state = samplingState
        let error = lastError
        let temperatures = temperatures
        let storage = storage
        let powerSource = powerSource
        stateLock.unlock()

        let age = sampleUptime.map { max(0, systemUptime - $0) }
        let health = HelperSamplingHealth(
            state: state,
            sequence: sequence,
            sampleAgeSeconds: age,
            intervalMilliseconds: Self.intervalMilliseconds,
            lastError: error
        )
        guard var sample = baseSample else {
            return (
                fallbackSample(
                    state: state,
                    error: error,
                    temperatures: temperatures,
                    storage: storage,
                    powerSource: powerSource,
                    sequence: sequence
                ),
                health
            )
        }

        sample.powerSource = powerSource
        merge(temperatures: temperatures, storage: storage, into: &sample)
        sample.helperSampleSequence = sequence
        sample.helperSampleAgeSeconds = age
        sample.samplingIntervalMilliseconds = Self.intervalMilliseconds
        sample.sourceDetail = "powermetrics 常驻流 500 ms · 温度/风扇 1 s · 电源/硬盘 5 s"

        if let age, age > 2 {
            sample.isDegraded = true
            appendMessage("Helper 缓存样本已延迟 \(String(format: "%.1f", age)) 秒，常驻采样流正在恢复。", to: &sample)
        } else if let error, state != "ready" {
            appendMessage("Helper 常驻采样流正在恢复：\(error)", to: &sample)
        }
        return (sample, health)
    }

    private func runPowermetricsLoop() {
        var retryDelay: TimeInterval = 0.25
        while !isStopped {
            guard isDemandActive else {
                setIdleState()
                waitForDemand()
                continue
            }
            setSamplingState(currentSequence == 0 ? "starting" : "restarting", error: nil)
            do {
                let parsedCount = try runContinuousPowermetrics()
                if isStopped { return }
                if !isDemandActive {
                    setIdleState()
                    retryDelay = 0.25
                    continue
                }
                setSamplingState("restarting", error: "powermetrics 流意外结束")
                retryDelay = parsedCount >= 3 ? 0.25 : min(5, retryDelay * 2)
            } catch {
                if isStopped { return }
                setSamplingState("restarting", error: error.localizedDescription)
                retryDelay = min(5, retryDelay * 2)
            }
            Thread.sleep(forTimeInterval: retryDelay)
        }
    }

    private func runContinuousPowermetrics() throws -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/powermetrics")
        process.arguments = [
            "-n", "-1",
            "-b", "0",
            "-i", String(Self.intervalMilliseconds),
            "--samplers", "cpu_power,gpu_power,thermal,ane_power",
            "--show-extra-power-info",
            "--handle-invalid-values",
            "-f", "plist"
        ]

        let stdout = Pipe()
        let readHandle = stdout.fileHandleForReading
        let writeHandle = stdout.fileHandleForWriting
        process.standardOutput = stdout
        process.standardError = FileHandle.standardError

        // Process/Pipe owns its descriptors and may close them asynchronously while a
        // terminated child is being reaped. Keep an independent descriptor for poll/read
        // so a previous powermetrics teardown cannot invalidate a newly reused fd.
        let descriptor = Darwin.dup(readHandle.fileDescriptor)
        guard descriptor >= 0 else {
            throw HelperSampleServiceError.streamSetupFailed(errnoText)
        }
        guard Darwin.fcntl(descriptor, F_SETFD, FD_CLOEXEC) == 0 else {
            let message = errnoText
            Darwin.close(descriptor)
            throw HelperSampleServiceError.streamSetupFailed(message)
        }

        stateLock.lock()
        self.process = process
        stateLock.unlock()
        var didLaunch = false
        defer {
            terminate(process, waitForExit: didLaunch)
            Darwin.close(descriptor)
            try? readHandle.close()
            try? writeHandle.close()
            stateLock.lock()
            if self.process === process {
                self.process = nil
            }
            stateLock.unlock()
        }

        guard !isStopped, isDemandActive else { return 0 }
        try process.run()
        didLaunch = true
        // Only the child needs the write end. The helper reads through its duplicated fd.
        try? writeHandle.close()
        try? readHandle.close()
        var pending = Data()
        var parsedCount = 0
        var lastDataUptime = systemUptime

        while !isStopped, isDemandActive, process.isRunning {
            var pollDescriptor = pollfd(fd: descriptor, events: Int16(POLLIN | POLLHUP | POLLERR), revents: 0)
            let pollResult = Darwin.poll(&pollDescriptor, 1, 1_000)
            if pollResult < 0 {
                if errno == EINTR { continue }
                throw HelperSampleServiceError.streamReadFailed(errnoText)
            }
            if pollResult == 0 {
                if systemUptime - lastDataUptime > 3 {
                    throw HelperSampleServiceError.streamTimedOut
                }
                continue
            }
            if (pollDescriptor.revents & Int16(POLLNVAL)) != 0 {
                throw HelperSampleServiceError.invalidStreamDescriptor
            }

            if (pollDescriptor.revents & Int16(POLLIN)) != 0 {
                var bytes = [UInt8](repeating: 0, count: 64 * 1024)
                let count = Darwin.read(descriptor, &bytes, bytes.count)
                if count > 0 {
                    lastDataUptime = systemUptime
                    pending.append(bytes, count: count)
                    parsedCount += consumePlistChunks(from: &pending)
                } else if count == 0 {
                    break
                } else if errno != EINTR && errno != EAGAIN {
                    throw HelperSampleServiceError.streamReadFailed(errnoText)
                }
            }
            if (pollDescriptor.revents & Int16(POLLHUP | POLLERR)) != 0,
               (pollDescriptor.revents & Int16(POLLIN)) == 0 {
                break
            }
        }

        if !pending.isEmpty {
            parsedCount += parseAndStore(chunk: pending) ? 1 : 0
        }
        if !isStopped, isDemandActive, parsedCount == 0 {
            throw HelperSampleServiceError.noSamples
        }
        return parsedCount
    }

    private func consumePlistChunks(from pending: inout Data) -> Int {
        var parsedCount = 0
        while let separator = pending.firstIndex(of: 0) {
            let chunk = Data(pending[..<separator])
            pending.removeSubrange(pending.startIndex...separator)
            if parseAndStore(chunk: chunk) {
                parsedCount += 1
            }
        }
        return parsedCount
    }

    private func parseAndStore(chunk: Data) -> Bool {
        guard !chunk.isEmpty else { return false }
        do {
            var sample = try PowermetricsParser.parse(
                output: chunk,
                fallbackThermalState: ThermalStateReader.current(),
                powerSource: currentPowerSource,
                sampleIntervalSeconds: Double(Self.intervalMilliseconds) / 1000
            )
            stateLock.lock()
            if let lastStoredCapturedAt, sample.capturedAt <= lastStoredCapturedAt {
                sample.capturedAt = lastStoredCapturedAt.addingTimeInterval(
                    Double(Self.intervalMilliseconds) / 1000
                )
            }
            lastStoredCapturedAt = sample.capturedAt
            sequence &+= 1
            sample.helperSampleSequence = sequence
            sample.helperSampleAgeSeconds = 0
            sample.samplingIntervalMilliseconds = Self.intervalMilliseconds
            latestSample = sample
            latestSampleUptime = systemUptime
            samplingState = "ready"
            lastError = nil
            stateLock.unlock()
            return true
        } catch {
            setSamplingState("restarting", error: error.localizedDescription)
            return false
        }
    }

    private func runSensorLoop() {
        var lastSlowRefreshUptime: TimeInterval = -Double.infinity
        while !isStopped {
            guard isDemandActive else {
                waitForDemand()
                continue
            }
            let cycleStarted = systemUptime
            let temperatures = HIDTemperatureReader.read()
            var storage: StorageTemperatureSnapshot?
            var powerSource: PowerSourceSnapshot?
            if cycleStarted - lastSlowRefreshUptime >= 5 {
                storage = StorageTemperatureReader.read()
                powerSource = PowerSourceReader.read()
                lastSlowRefreshUptime = cycleStarted
            }

            stateLock.lock()
            self.temperatures = temperatures
            if let storage { self.storage = storage }
            if let powerSource { self.powerSource = powerSource }
            stateLock.unlock()

            let elapsed = systemUptime - cycleStarted
            Thread.sleep(forTimeInterval: max(0.1, 1 - elapsed))
        }
    }

    private func fallbackSample(
        state: String,
        error: String?,
        temperatures: HIDTemperatureSnapshot?,
        storage: StorageTemperatureSnapshot,
        powerSource: PowerSourceSnapshot,
        sequence: UInt64
    ) -> TelemetrySample {
        var sample = TelemetrySample(
            capturedAt: Date(),
            source: .fallback,
            sourceDetail: "Helper 常驻采样流 \(state)",
            thermalState: ThermalStateReader.current(),
            thermalPressure: nil,
            cpuPowerW: nil,
            gpuPowerW: nil,
            anePowerW: nil,
            packagePowerW: nil,
            cpuActivePercent: nil,
            gpuActivePercent: nil,
            eClusterFrequencyMHz: nil,
            pClusterFrequencyMHz: nil,
            gpuFrequencyMHz: nil,
            cpuTemperatureC: nil,
            gpuTemperatureC: nil,
            socTemperatureC: nil,
            powerSource: powerSource,
            isDegraded: true,
            message: error.map { "Helper 常驻采样流正在恢复：\($0)" } ?? "Helper 正在等待第一条 powermetrics 样本。",
            helperSampleSequence: sequence,
            samplingIntervalMilliseconds: Self.intervalMilliseconds
        )
        merge(temperatures: temperatures, storage: storage, into: &sample)
        return sample
    }

    private func merge(
        temperatures: HIDTemperatureSnapshot?,
        storage: StorageTemperatureSnapshot,
        into sample: inout TelemetrySample
    ) {
        if let temperatures {
            sample.cpuTemperatureC = temperatures.cpuTemperatureC
            sample.gpuTemperatureC = temperatures.gpuTemperatureC
            sample.socTemperatureC = temperatures.socTemperatureC
            sample.temperatureSourceDetail = temperatures.sourceDetail
            sample.cpuTemperatureSensorCount = temperatures.cpuSensorCount
            sample.gpuTemperatureSensorCount = temperatures.gpuSensorCount
            sample.socTemperatureSensorCount = temperatures.socSensorCount
            sample.fanRPMs = temperatures.fanRPMs
            sample.ssdTemperatureC = temperatures.ssdTemperatureC
            sample.wifiTemperatureC = temperatures.wifiTemperatureC
            sample.airflowTemperatureC = temperatures.airflowTemperatureC
            sample.ambientTemperatureC = temperatures.ambientTemperatureC
        }
        sample.diskTemperatureC = storage.diskTemperatureC
        sample.diskTemperatureSourceDetail = storage.sourceDetail
    }

    private func setSamplingState(_ state: String, error: String?) {
        stateLock.lock()
        samplingState = state
        if let error { lastError = error }
        stateLock.unlock()
    }

    private func setIdleState() {
        stateLock.lock()
        samplingState = "idle"
        lastError = nil
        stateLock.unlock()
    }

    private func markDemand() {
        demandCondition.lock()
        stateLock.lock()
        lastDemandUptime = systemUptime
        if samplingState == "idle" {
            samplingState = "starting"
        }
        stateLock.unlock()
        demandCondition.broadcast()
        demandCondition.unlock()
    }

    private func waitForDemand() {
        demandCondition.lock()
        if !isStopped, !isDemandActive {
            demandCondition.wait()
        }
        demandCondition.unlock()
    }

    private var currentPowerSource: PowerSourceSnapshot {
        stateLock.lock()
        let snapshot = powerSource
        stateLock.unlock()
        return snapshot
    }

    private var currentSequence: UInt64 {
        stateLock.lock()
        let value = sequence
        stateLock.unlock()
        return value
    }

    private var isStopped: Bool {
        stateLock.lock()
        let value = stopped
        stateLock.unlock()
        return value
    }

    private var isDemandActive: Bool {
        stateLock.lock()
        let lastDemandUptime = lastDemandUptime
        stateLock.unlock()
        guard let lastDemandUptime else { return false }
        return systemUptime - lastDemandUptime <= Self.idleTimeout
    }

    private var systemUptime: TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    private var errnoText: String {
        String(cString: strerror(errno))
    }

    private func appendMessage(_ message: String, to sample: inout TelemetrySample) {
        if let existing = sample.message, !existing.isEmpty {
            sample.message = "\(existing)\n\(message)"
        } else {
            sample.message = message
        }
    }

    private func terminate(_ process: Process?, waitForExit: Bool = false) {
        guard let process else { return }
        processTerminationLock.lock()
        defer { processTerminationLock.unlock() }

        let wasRunning = process.isRunning
        if wasRunning {
            process.terminate()
            let deadline = Date().addingTimeInterval(0.5)
            while process.isRunning, Date() < deadline {
                Thread.sleep(forTimeInterval: 0.02)
            }
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
        }
        if waitForExit || wasRunning {
            process.waitUntilExit()
        }
    }

    deinit {
        stop()
    }
}

private enum HelperSampleServiceError: LocalizedError {
    case streamSetupFailed(String)
    case streamTimedOut
    case invalidStreamDescriptor
    case streamReadFailed(String)
    case noSamples

    var errorDescription: String? {
        switch self {
        case .streamSetupFailed(let message):
            return "powermetrics 常驻流管道创建失败：\(message)"
        case .streamTimedOut:
            return "powermetrics 常驻流超过 3 秒没有新数据"
        case .invalidStreamDescriptor:
            return "powermetrics 常驻流管道已失效"
        case .streamReadFailed(let message):
            return "powermetrics 常驻流读取失败：\(message)"
        case .noSamples:
            return "powermetrics 常驻流未产生有效样本"
        }
    }
}
