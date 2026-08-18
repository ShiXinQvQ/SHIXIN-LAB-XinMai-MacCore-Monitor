// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import Darwin
import Foundation
import ShixinStressPowerCore
import SystemConfiguration

enum NetworkSpeedTestPhase: Equatable {
    case idle
    case preparing
    case measuring
    case analyzing
    case completed
    case failed

    var isRunning: Bool {
        switch self {
        case .preparing, .measuring, .analyzing:
            return true
        case .idle, .completed, .failed:
            return false
        }
    }

    var title: String {
        switch self {
        case .idle: "准备就绪"
        case .preparing: "正在测量延迟与抖动"
        case .measuring: "正在测量下载与上传"
        case .analyzing: "正在整理测速结果"
        case .completed: "测试完成"
        case .failed: "测试未完成"
        }
    }
}

@MainActor
final class NetworkSpeedTestController: ObservableObject {
    @Published private(set) var phase: NetworkSpeedTestPhase = .idle
    @Published private(set) var progress = 0.0
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var currentResult: NetworkSpeedTestRecord?
    @Published private(set) var liveMeasurement: NetworkQualityLiveMeasurement?
    @Published private(set) var liveLatencyMilliseconds: Double?
    @Published private(set) var liveJitterMilliseconds: Double?
    @Published private(set) var liveDownloadMbps: Double?
    @Published private(set) var liveUploadMbps: Double?
    @Published private(set) var liveDownloadedBytes: Int64?
    @Published private(set) var liveUploadedBytes: Int64?
    @Published private(set) var liveTrafficInterfaceName: String?
    @Published private(set) var history: [NetworkSpeedTestRecord] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var historyWarning: String?

    private let historyStore: NetworkSpeedHistoryStore
    private let processRunner = NetworkQualityProcessRunner()
    private let latencyProbe = HTTPSLatencyProbe()
    private var runTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private var trafficSamplingTask: Task<Void, Never>?

    init(historyStore: NetworkSpeedHistoryStore = NetworkSpeedHistoryStore()) {
        self.historyStore = historyStore
        do {
            history = try historyStore.load()
        } catch {
            historyWarning = "网速历史读取失败：\(error.localizedDescription)"
        }
    }

    var displayResult: NetworkSpeedTestRecord? {
        currentResult ?? history.first
    }

    var historyURL: URL {
        historyStore.historyURL
    }

    func startTest() {
        guard !phase.isRunning, runTask == nil else { return }

        progressTask?.cancel()
        processRunner.resetCancellation()

        let startedAt = Date()
        phase = .preparing
        progress = 0.04
        elapsedSeconds = 0
        currentResult = nil
        liveMeasurement = nil
        liveLatencyMilliseconds = nil
        liveJitterMilliseconds = nil
        liveDownloadMbps = 0
        liveUploadMbps = 0
        liveDownloadedBytes = 0
        liveUploadedBytes = 0
        liveTrafficInterfaceName = nil
        errorMessage = nil
        historyWarning = nil
        startProgressClock(startedAt: startedAt)

        runTask = Task { [weak self] in
            guard let self else { return }
            do {
                let probe = try await latencyProbe.measure()
                try Task.checkCancellation()
                liveLatencyMilliseconds = probe?.medianMilliseconds
                liveJitterMilliseconds = probe?.jitterMilliseconds

                phase = .measuring
                progress = max(progress, 0.20)
                startTrafficSampling()
                let output = try await processRunner.run(maxRuntimeSeconds: 35) { [weak self] update in
                    Task { @MainActor [weak self] in
                        self?.applyLiveMeasurement(update)
                    }
                }
                try Task.checkCancellation()
                stopTrafficSampling(resetValues: false)

                phase = .analyzing
                progress = max(progress, 0.95)
                let measurement = try NetworkQualityParser.parse(data: output)
                guard let latency = measurement.latencyMilliseconds ?? probe?.medianMilliseconds else {
                    throw NetworkSpeedTestError.missingMeasurement
                }

                let completedAt = Date()
                let record = NetworkSpeedTestRecord(
                    startedAt: startedAt,
                    completedAt: completedAt,
                    downloadMbps: measurement.downloadMbps,
                    uploadMbps: measurement.uploadMbps,
                    latencyMilliseconds: latency,
                    jitterMilliseconds: probe?.jitterMilliseconds,
                    responsivenessRPM: measurement.responsivenessRPM,
                    downlinkResponsivenessRPM: measurement.downlinkResponsivenessRPM,
                    uplinkResponsivenessRPM: measurement.uplinkResponsivenessRPM,
                    downloadedBytes: measurement.downloadedBytes,
                    uploadedBytes: measurement.uploadedBytes,
                    interfaceName: measurement.interfaceName,
                    serverName: measurement.testEndpointHost ?? "macOS 默认网络质量服务"
                )

                currentResult = record
                do {
                    history = try historyStore.append(record)
                } catch {
                    historyWarning = "测速成功，但历史保存失败：\(error.localizedDescription)"
                }
                elapsedSeconds = completedAt.timeIntervalSince(startedAt)
                progress = 1
                phase = .completed
            } catch is CancellationError {
                stopTrafficSampling(resetValues: true)
                phase = .idle
                progress = 0
                elapsedSeconds = 0
            } catch {
                stopTrafficSampling(resetValues: true)
                errorMessage = error.localizedDescription
                phase = .failed
                progress = 0
            }
            progressTask?.cancel()
            progressTask = nil
            runTask = nil
        }
    }

    func cancelTest() {
        guard phase.isRunning else { return }
        runTask?.cancel()
        processRunner.cancel()
        progressTask?.cancel()
        progressTask = nil
        stopTrafficSampling(resetValues: true)
        phase = .idle
        progress = 0
        elapsedSeconds = 0
        liveMeasurement = nil
        liveLatencyMilliseconds = nil
        liveJitterMilliseconds = nil
        errorMessage = nil
    }

    private func startProgressClock(startedAt: Date) {
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                elapsedSeconds = Date().timeIntervalSince(startedAt)
                switch phase {
                case .preparing:
                    progress = max(progress, min(0.18, 0.04 + elapsedSeconds * 0.025))
                case .measuring:
                    let estimatedMeasurementProgress = 0.20 + min(1, elapsedSeconds / 35) * 0.72
                    progress = max(progress, min(0.92, estimatedMeasurementProgress))
                case .analyzing:
                    progress = max(progress, 0.95)
                case .idle, .completed, .failed:
                    return
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    private func startTrafficSampling() {
        stopTrafficSampling(resetValues: false)

        let interfaceName = NetworkInterfaceTrafficSampler.primaryInterfaceName()
        liveTrafficInterfaceName = interfaceName
        liveDownloadMbps = 0
        liveUploadMbps = 0
        liveDownloadedBytes = 0
        liveUploadedBytes = 0

        trafficSamplingTask = Task { [weak self] in
            guard let self else { return }
            var sampledInterface = interfaceName
            var previousSnapshot = NetworkInterfaceTrafficSampler.snapshot(
                interfaceName: sampledInterface
            )
            var previousTime = Date()
            var totalReceivedBytes: UInt64 = 0
            var totalSentBytes: UInt64 = 0
            var smoothedDownloadMbps = 0.0
            var smoothedUploadMbps = 0.0

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 150_000_000)
                } catch {
                    return
                }
                guard phase == .measuring else { return }

                let reportedInterface = liveMeasurement?.interfaceName
                if let reportedInterface,
                   !reportedInterface.isEmpty,
                   reportedInterface != sampledInterface {
                    sampledInterface = reportedInterface
                    liveTrafficInterfaceName = reportedInterface
                    previousSnapshot = NetworkInterfaceTrafficSampler.snapshot(
                        interfaceName: reportedInterface
                    )
                    previousTime = Date()
                    continue
                }

                guard let currentSnapshot = NetworkInterfaceTrafficSampler.snapshot(
                    interfaceName: sampledInterface
                ) else {
                    continue
                }
                if sampledInterface == nil {
                    sampledInterface = currentSnapshot.interfaceName
                    liveTrafficInterfaceName = currentSnapshot.interfaceName
                }
                guard let lastSnapshot = previousSnapshot else {
                    previousSnapshot = currentSnapshot
                    previousTime = Date()
                    continue
                }

                let now = Date()
                let elapsed = max(0.001, now.timeIntervalSince(previousTime))
                let receivedDelta = NetworkInterfaceTrafficSampler.byteDelta(
                    current: currentSnapshot.receivedBytes,
                    previous: lastSnapshot.receivedBytes
                )
                let sentDelta = NetworkInterfaceTrafficSampler.byteDelta(
                    current: currentSnapshot.sentBytes,
                    previous: lastSnapshot.sentBytes
                )
                totalReceivedBytes += receivedDelta
                totalSentBytes += sentDelta

                let currentDownloadMbps = Double(receivedDelta) * 8 / elapsed / 1_000_000
                let currentUploadMbps = Double(sentDelta) * 8 / elapsed / 1_000_000
                smoothedDownloadMbps = smoothedValue(
                    previous: smoothedDownloadMbps,
                    current: currentDownloadMbps
                )
                smoothedUploadMbps = smoothedValue(
                    previous: smoothedUploadMbps,
                    current: currentUploadMbps
                )

                liveDownloadMbps = smoothedDownloadMbps
                liveUploadMbps = smoothedUploadMbps
                liveDownloadedBytes = Int64(clamping: totalReceivedBytes)
                liveUploadedBytes = Int64(clamping: totalSentBytes)
                previousSnapshot = currentSnapshot
                previousTime = now
            }
        }
    }

    private func stopTrafficSampling(resetValues: Bool) {
        trafficSamplingTask?.cancel()
        trafficSamplingTask = nil
        if resetValues {
            liveDownloadMbps = nil
            liveUploadMbps = nil
            liveDownloadedBytes = nil
            liveUploadedBytes = nil
            liveTrafficInterfaceName = nil
        }
    }

    private func smoothedValue(previous: Double, current: Double) -> Double {
        guard previous > 0 else { return current }
        return previous * 0.55 + current * 0.45
    }

    private func applyLiveMeasurement(_ update: NetworkQualityLiveMeasurement) {
        guard phase == .measuring || phase == .analyzing else { return }
        let previous = liveMeasurement
        liveMeasurement = NetworkQualityLiveMeasurement(
            fractionCompleted: update.fractionCompleted ?? previous?.fractionCompleted,
            downloadMbps: update.downloadMbps ?? previous?.downloadMbps,
            uploadMbps: update.uploadMbps ?? previous?.uploadMbps,
            latencyMilliseconds: update.latencyMilliseconds ?? previous?.latencyMilliseconds,
            responsivenessRPM: update.responsivenessRPM ?? previous?.responsivenessRPM,
            downlinkResponsivenessRPM: update.downlinkResponsivenessRPM
                ?? previous?.downlinkResponsivenessRPM,
            uplinkResponsivenessRPM: update.uplinkResponsivenessRPM
                ?? previous?.uplinkResponsivenessRPM,
            downloadedBytes: update.downloadedBytes ?? previous?.downloadedBytes,
            uploadedBytes: update.uploadedBytes ?? previous?.uploadedBytes,
            interfaceName: update.interfaceName ?? previous?.interfaceName,
            testEndpointHost: update.testEndpointHost ?? previous?.testEndpointHost
        )
        if let fractionCompleted = update.fractionCompleted {
            progress = max(progress, min(0.92, 0.20 + fractionCompleted * 0.72))
        }
    }
}

private struct NetworkInterfaceByteSnapshot: Sendable {
    let interfaceName: String
    let receivedBytes: UInt64
    let sentBytes: UInt64
}

private enum NetworkInterfaceTrafficSampler {
    static func primaryInterfaceName() -> String? {
        for key in [
            "State:/Network/Global/IPv4",
            "State:/Network/Global/IPv6"
        ] {
            guard let value = SCDynamicStoreCopyValue(nil, key as CFString)
                    as? [String: Any],
                  let interfaceName = value["PrimaryInterface"] as? String,
                  !interfaceName.isEmpty else {
                continue
            }
            return interfaceName
        }
        return nil
    }

    static func snapshot(interfaceName: String?) -> NetworkInterfaceByteSnapshot? {
        let targetName = interfaceName ?? primaryInterfaceName()
        guard let targetName else { return nil }

        var addressList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressList) == 0, let addressList else { return nil }
        defer { freeifaddrs(addressList) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = addressList
        while let current = cursor {
            cursor = current.pointee.ifa_next
            guard String(cString: current.pointee.ifa_name) == targetName,
                  let address = current.pointee.ifa_addr,
                  Int32(address.pointee.sa_family) == AF_LINK,
                  let rawData = current.pointee.ifa_data else {
                continue
            }

            let data = rawData.assumingMemoryBound(to: if_data.self).pointee
            return NetworkInterfaceByteSnapshot(
                interfaceName: targetName,
                receivedBytes: UInt64(data.ifi_ibytes),
                sentBytes: UInt64(data.ifi_obytes)
            )
        }
        return nil
    }

    static func byteDelta(current: UInt64, previous: UInt64) -> UInt64 {
        guard current < previous else { return current - previous }
        return UInt64(UInt32.max) - previous + current + 1
    }
}

private struct HTTPSLatencyMeasurement: Sendable {
    let medianMilliseconds: Double
    let jitterMilliseconds: Double
}

private struct HTTPSLatencyProbe: Sendable {
    private let endpoint = URL(string: "https://www.apple.com/library/test/success.html")!
    private let sampleCount = 7

    func measure() async throws -> HTTPSLatencyMeasurement? {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 7
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        var samples: [Double] = []
        for index in 0..<sampleCount {
            try Task.checkCancellation()
            var request = URLRequest(url: endpoint)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 5
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

            let startedAt = Date()
            do {
                let (_, response) = try await session.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   (200..<400).contains(httpResponse.statusCode) {
                    samples.append(Date().timeIntervalSince(startedAt) * 1_000)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // A blocked probe should not prevent the system networkQuality test.
            }

            if index < sampleCount - 1 {
                try await Task.sleep(nanoseconds: 80_000_000)
            }
        }

        guard samples.count >= 3 else { return nil }
        let sorted = samples.sorted()
        let median: Double
        if sorted.count.isMultiple(of: 2) {
            median = (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
        } else {
            median = sorted[sorted.count / 2]
        }

        let differences = zip(samples.dropFirst(), samples).map { abs($0 - $1) }
        let jitter = differences.reduce(0, +) / Double(differences.count)
        return HTTPSLatencyMeasurement(
            medianMilliseconds: median,
            jitterMilliseconds: jitter
        )
    }
}

private final class NetworkQualityProcessRunner: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancellationRequested = false

    func run(
        maxRuntimeSeconds: Int,
        onProgress: @escaping @Sendable (NetworkQualityLiveMeasurement) -> Void
    ) async throws -> Data {
        try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) {
                try self.runBlocking(
                    maxRuntimeSeconds: maxRuntimeSeconds,
                    onProgress: onProgress
                )
            }.value
        } onCancel: {
            self.cancel()
        }
    }

    func cancel() {
        lock.lock()
        cancellationRequested = true
        let runningProcess = process
        lock.unlock()
        if runningProcess?.isRunning == true {
            runningProcess?.terminate()
        }
    }

    func resetCancellation() {
        lock.lock()
        cancellationRequested = false
        lock.unlock()
    }

    private func runBlocking(
        maxRuntimeSeconds: Int,
        onProgress: @escaping @Sendable (NetworkQualityLiveMeasurement) -> Void
    ) throws -> Data {
        let process = Process()
        let combinedOutput = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/networkQuality")
        process.arguments = ["-c", "-M", String(max(10, maxRuntimeSeconds))]
        process.standardOutput = combinedOutput
        process.standardError = combinedOutput

        lock.lock()
        if cancellationRequested {
            lock.unlock()
            throw CancellationError()
        }
        self.process = process
        lock.unlock()

        defer {
            lock.lock()
            self.process = nil
            lock.unlock()
        }

        do {
            try process.run()
        } catch {
            throw NetworkSpeedTestError.processFailed(
                status: -1,
                message: error.localizedDescription
            )
        }

        lock.lock()
        let shouldCancel = cancellationRequested
        lock.unlock()
        if shouldCancel, process.isRunning {
            process.terminate()
        }

        var output = Data()
        var previousUpdate: NetworkQualityLiveMeasurement?
        while true {
            let chunk = combinedOutput.fileHandleForReading.availableData
            guard !chunk.isEmpty else { break }
            output.append(chunk)
            if let update = NetworkQualityParser.latestLiveMeasurement(in: output),
               update != previousUpdate {
                previousUpdate = update
                onProgress(update)
            }
        }
        process.waitUntilExit()

        lock.lock()
        let wasCancelled = cancellationRequested
        lock.unlock()
        if wasCancelled {
            throw CancellationError()
        }

        if process.terminationStatus != 0 {
            do {
                _ = try NetworkQualityParser.parse(data: output)
                return output
            } catch let error as NetworkSpeedTestError {
                if case .networkQualityFailure = error {
                    throw error
                }
            } catch {
                // Fall through to the process-level message below.
            }

            let message = String(data: output, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw NetworkSpeedTestError.processFailed(
                status: process.terminationStatus,
                message: message
            )
        }
        return output
    }
}
