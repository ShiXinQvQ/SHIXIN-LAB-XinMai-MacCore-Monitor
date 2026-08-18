// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

@preconcurrency import CoreLocation
import CoreWLAN
import Darwin
import Foundation
import Network
import ShixinNetworkDiagnosticsCore
import ShixinStressPowerCore
import SystemConfiguration

enum InternationalDiagnosticsPhase: Equatable {
    case idle
    case preparing
    case probing
    case analyzing
    case completed
    case partial
    case failed
    case cancelled

    var isRunning: Bool {
        switch self {
        case .preparing, .probing, .analyzing:
            true
        case .idle, .completed, .partial, .failed, .cancelled:
            false
        }
    }

    var titleKey: String {
        switch self {
        case .idle: "准备诊断"
        case .preparing: "正在检查网络路径"
        case .probing: "正在诊断国际连通性"
        case .analyzing: "正在生成可解释结论"
        case .completed: "诊断完成"
        case .partial: "诊断部分完成"
        case .failed: "诊断未完成"
        case .cancelled: "诊断已取消"
        }
    }
}

@MainActor
final class InternationalDiagnosticsController: ObservableObject {
    @Published private(set) var phase: InternationalDiagnosticsPhase = .idle
    @Published private(set) var progress = 0.0
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var targetResults: [InternationalTargetResult] = []
    @Published private(set) var currentRecord: NetworkDiagnosticsRecord?
    @Published private(set) var history: [NetworkDiagnosticsRecord] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var historyWarning: String?
    @Published var includesIPAnalysis = false

    private let historyStore: NetworkDiagnosticsHistoryStore
    private let probeService = InternationalConnectivityService()
    private let localDetailsReader = LocalNetworkDetailsReader()
    private let intelligenceService = PublicNetworkIntelligenceService()
    private var runTask: Task<Void, Never>?
    private var elapsedTask: Task<Void, Never>?

    init(
        historyStore: NetworkDiagnosticsHistoryStore = NetworkDiagnosticsHistoryStore()
    ) {
        self.historyStore = historyStore
        do {
            history = try historyStore.load()
        } catch {
            historyWarning = "国际诊断历史读取失败：\(error.localizedDescription)"
        }
    }

    var displayRecord: NetworkDiagnosticsRecord? {
        if let currentRecord {
            return currentRecord
        }
        return phase == .idle ? history.first : nil
    }

    var displayTargetResults: [InternationalTargetResult] {
        if phase == .idle, targetResults.isEmpty {
            return displayRecord?.targets ?? []
        }
        return targetResults
    }

    var historyURL: URL {
        historyStore.historyURL
    }

    func start() {
        guard !phase.isRunning, runTask == nil else { return }

        let startedAt = Date()
        targetResults = []
        currentRecord = nil
        errorMessage = nil
        historyWarning = nil
        elapsedSeconds = 0
        progress = 0.03
        phase = .preparing
        startElapsedClock(startedAt: startedAt)

        let includeIPAnalysis = includesIPAnalysis
        runTask = Task { [weak self] in
            guard let self else { return }
            do {
                try Task.checkCancellation()
                phase = .probing
                progress = 0.08

                let endpoints = InternationalConnectivityService.defaultEndpoints
                let probeService = self.probeService
                let results = try await withThrowingTaskGroup(
                    of: InternationalTargetResult.self
                ) { group in
                    for endpoint in endpoints {
                        group.addTask {
                            try await probeService.probe(endpoint: endpoint)
                        }
                    }

                    var completed: [InternationalTargetResult] = []
                    for try await result in group {
                        try Task.checkCancellation()
                        completed.append(result)
                        self.targetResults = completed.sorted {
                            endpointOrder($0.id) < endpointOrder($1.id)
                        }
                        self.progress = 0.08
                            + Double(completed.count) / Double(endpoints.count) * 0.68
                    }
                    return completed.sorted {
                        endpointOrder($0.id) < endpointOrder($1.id)
                    }
                }

                try Task.checkCancellation()
                targetResults = results
                phase = .analyzing
                progress = 0.80

                var publicSnapshot: PublicNetworkIntelligenceSnapshot?
                var localSnapshot: LocalNetworkDetailsSnapshot?
                if includeIPAnalysis {
                    async let local = localDetailsReader.read()
                    async let intelligence = intelligenceService.query()
                    localSnapshot = await local
                    publicSnapshot = await intelligence
                }

                try Task.checkCancellation()
                let international = InternationalAssessmentEngine.assess(results)
                let reputation = includeIPAnalysis
                    ? IPReputationAssessmentEngine.assess(publicSnapshot?.riskProfile)
                    : nil
                let privacyInput = includeIPAnalysis
                    ? NetworkPrivacyInputBuilder.make(
                        local: localSnapshot,
                        publicSnapshot: publicSnapshot
                    )
                    : nil
                let privacy = includeIPAnalysis
                    ? PrivacyConsistencyAssessmentEngine.assess(privacyInput)
                    : nil
                let combined = CombinedNetworkAssessmentEngine.assess(
                    international: international,
                    reputation: reputation,
                    privacy: privacy
                )
                let record = NetworkDiagnosticsRecord(
                    startedAt: startedAt,
                    completedAt: Date(),
                    targets: results,
                    internationalAssessment: international,
                    publicSummary: publicSnapshot?.historySummary,
                    reputationAssessment: reputation,
                    privacyAssessment: privacy,
                    combinedAssessment: combined
                )
                currentRecord = record

                do {
                    history = try historyStore.append(record)
                } catch {
                    historyWarning = "国际诊断历史保存失败：\(error.localizedDescription)"
                }

                let unavailableCount = results.filter {
                    InternationalAssessmentEngine.targetStatus($0) == .unavailable
                }.count
                if results.isEmpty {
                    phase = .failed
                } else if unavailableCount > 0 || publicSnapshot?.hasProviderFailure == true {
                    phase = .partial
                } else {
                    phase = .completed
                }
                progress = 1
            } catch is CancellationError {
                phase = .cancelled
                errorMessage = nil
            } catch {
                phase = .failed
                errorMessage = "国际诊断失败：\(error.localizedDescription)"
            }

            elapsedTask?.cancel()
            elapsedTask = nil
            runTask = nil
        }
    }

    func cancel() {
        guard phase.isRunning else { return }
        runTask?.cancel()
        elapsedTask?.cancel()
        phase = .cancelled
    }

    private func startElapsedClock(startedAt: Date) {
        elapsedTask?.cancel()
        elapsedTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                elapsedSeconds = Date().timeIntervalSince(startedAt)
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }
}

private func endpointOrder(_ id: InternationalTargetID) -> Int {
    InternationalTargetID.allCases.firstIndex(of: id) ?? .max
}

struct InternationalProbeEndpoint: Sendable {
    let id: InternationalTargetID
    let url: URL
}

struct DNSResolutionResult: Sendable {
    let milliseconds: Double
    let hasIPv4: Bool
    let hasIPv6: Bool
    let errorKind: InternationalProbeErrorKind?
    let errorDescription: String?
}

struct InternationalConnectivityService: Sendable {
    static let defaultEndpoints: [InternationalProbeEndpoint] = [
        .init(
            id: .google,
            url: URL(string: "https://www.google.com/generate_204")!
        ),
        .init(
            id: .youtube,
            url: URL(string: "https://www.youtube.com/generate_204")!
        ),
        .init(
            id: .x,
            url: URL(string: "https://x.com/robots.txt")!
        ),
        .init(
            id: .instagram,
            url: URL(string: "https://www.instagram.com/robots.txt")!
        ),
        .init(
            id: .github,
            url: URL(string: "https://github.com/robots.txt")!
        )
    ]

    private let attemptCount = 3

    func probe(endpoint: InternationalProbeEndpoint) async throws -> InternationalTargetResult {
        var attempts: [InternationalProbeAttempt] = []
        for index in 0..<attemptCount {
            try Task.checkCancellation()
            attempts.append(try await probeOnce(endpoint: endpoint))
            if index < attemptCount - 1 {
                try await Task.sleep(nanoseconds: 140_000_000)
            }
        }
        return InternationalTargetResult(
            id: endpoint.id,
            requestedHost: endpoint.url.host,
            requestedAttemptCount: attemptCount,
            attempts: attempts
        )
    }

    private func probeOnce(
        endpoint: InternationalProbeEndpoint
    ) async throws -> InternationalProbeAttempt {
        let startedAt = Date()
        let resolution = try await DNSResolver.resolve(
            host: endpoint.url.host ?? endpoint.id.host
        )
        try Task.checkCancellation()

        guard resolution.hasIPv4 || resolution.hasIPv6 else {
            return InternationalProbeAttempt(
                startedAt: startedAt,
                dnsMilliseconds: resolution.milliseconds,
                connectMilliseconds: nil,
                tlsMilliseconds: nil,
                ttfbMilliseconds: nil,
                totalMilliseconds: Date().timeIntervalSince(startedAt) * 1_000,
                statusCode: nil,
                finalHost: endpoint.url.host,
                resolvedIPv4: false,
                resolvedIPv6: false,
                usedIPVersion: nil,
                usedProxy: nil,
                errorKind: resolution.errorKind ?? .dnsFailure,
                errorDescription: resolution.errorDescription
            )
        }

        var request = URLRequest(url: endpoint.url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 8
        request.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("bytes=0-16383", forHTTPHeaderField: "Range")
        request.setValue(
            "SHIXIN-LAB-XinMai-Network-Diagnostics/0.3",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("*/*", forHTTPHeaderField: "Accept")

        do {
            let output = try await HTTPMetricsRequest.run(request: request)
            let statusCode = output.response?.statusCode
            let httpAbnormal = statusCode.map { !(200..<400).contains($0) } ?? true
            return InternationalProbeAttempt(
                startedAt: startedAt,
                dnsMilliseconds: output.metrics.dnsMilliseconds
                    ?? resolution.milliseconds,
                connectMilliseconds: output.metrics.connectMilliseconds,
                tlsMilliseconds: output.metrics.tlsMilliseconds,
                ttfbMilliseconds: output.metrics.ttfbMilliseconds,
                totalMilliseconds: output.metrics.totalMilliseconds
                    ?? Date().timeIntervalSince(startedAt) * 1_000,
                statusCode: statusCode,
                responseBytes: output.responseBytes,
                finalHost: output.response?.url?.host ?? endpoint.url.host,
                redirectCount: output.metrics.redirectCount,
                resolvedIPv4: resolution.hasIPv4,
                resolvedIPv6: resolution.hasIPv6,
                usedIPVersion: Self.ipVersion(of: output.metrics.remoteAddress),
                usedProxy: output.metrics.usedProxy,
                errorKind: output.responseTooLarge
                    ? .responseTooLarge
                    : (httpAbnormal ? .httpAbnormal : nil),
                errorDescription: output.responseTooLarge
                    ? "Response exceeded the diagnostic byte limit."
                    : nil
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return InternationalProbeAttempt(
                startedAt: startedAt,
                dnsMilliseconds: resolution.milliseconds,
                connectMilliseconds: nil,
                tlsMilliseconds: nil,
                ttfbMilliseconds: nil,
                totalMilliseconds: Date().timeIntervalSince(startedAt) * 1_000,
                statusCode: nil,
                finalHost: endpoint.url.host,
                resolvedIPv4: resolution.hasIPv4,
                resolvedIPv6: resolution.hasIPv6,
                usedIPVersion: nil,
                usedProxy: nil,
                errorKind: Self.errorKind(for: error),
                errorDescription: Self.safeErrorDescription(error)
            )
        }
    }

    private static func ipVersion(of address: String?) -> String? {
        guard let address else { return nil }
        return address.contains(":") ? "IPv6" : "IPv4"
    }

    private static func errorKind(for error: Error) -> InternationalProbeErrorKind {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return .unknown }
        switch nsError.code {
        case NSURLErrorTimedOut:
            return .timeout
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorDataNotAllowed:
            return .offline
        case NSURLErrorCannotFindHost,
             NSURLErrorDNSLookupFailed:
            return .dnsFailure
        case NSURLErrorCannotConnectToHost:
            return .connectionFailure
        case NSURLErrorSecureConnectionFailed,
             NSURLErrorServerCertificateHasBadDate,
             NSURLErrorServerCertificateUntrusted,
             NSURLErrorServerCertificateHasUnknownRoot,
             NSURLErrorServerCertificateNotYetValid,
             NSURLErrorClientCertificateRejected,
             NSURLErrorClientCertificateRequired:
            return .tlsFailure
        case NSURLErrorCancelled:
            return Task.isCancelled ? .cancelled : .connectionReset
        default:
            return .unknown
        }
    }

    private static func safeErrorDescription(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "NSURLErrorDomain \(nsError.code)"
        }
        return "\(nsError.domain) \(nsError.code)"
    }
}

private enum DNSResolver {
    static func resolve(host: String) async throws -> DNSResolutionResult {
        try await DNSResolutionRequest(host: host).run()
    }
}

private final class DNSResolutionRequest: @unchecked Sendable {
    private let host: String
    private let startedAt = Date()
    private let lock = NSLock()
    private var continuation: CheckedContinuation<DNSResolutionResult, Error>?
    private var completed = false
    private var cancellationRequested = false

    init(host: String) {
        self.host = host
    }

    func run() async throws -> DNSResolutionResult {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if cancellationRequested {
                    completed = true
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                    return
                }
                self.continuation = continuation
                lock.unlock()

                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    finish(.success(resolveSynchronously()))
                }
                DispatchQueue.global(qos: .userInitiated).asyncAfter(
                    deadline: .now() + 5
                ) { [self] in
                    finish(.success(DNSResolutionResult(
                        milliseconds: Date().timeIntervalSince(startedAt) * 1_000,
                        hasIPv4: false,
                        hasIPv6: false,
                        errorKind: .timeout,
                        errorDescription: "DNS timeout"
                    )))
                }
            }
        } onCancel: {
            cancel()
        }
    }

    private func cancel() {
        lock.lock()
        cancellationRequested = true
        guard !completed, let continuation else {
            lock.unlock()
            return
        }
        completed = true
        self.continuation = nil
        lock.unlock()
        continuation.resume(throwing: CancellationError())
    }

    private func resolveSynchronously() -> DNSResolutionResult {
        var hints = addrinfo(
            ai_flags: AI_ADDRCONFIG,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var results: UnsafeMutablePointer<addrinfo>?
        let code = getaddrinfo(host, "443", &hints, &results)
        defer {
            if let results {
                freeaddrinfo(results)
            }
        }

        var hasIPv4 = false
        var hasIPv6 = false
        var cursor = results
        while let current = cursor {
            if current.pointee.ai_family == AF_INET {
                hasIPv4 = true
            } else if current.pointee.ai_family == AF_INET6 {
                hasIPv6 = true
            }
            cursor = current.pointee.ai_next
        }
        let message = code == 0 ? nil : String(cString: gai_strerror(code))
        return DNSResolutionResult(
            milliseconds: Date().timeIntervalSince(startedAt) * 1_000,
            hasIPv4: hasIPv4,
            hasIPv6: hasIPv6,
            errorKind: code == 0 ? nil : .dnsFailure,
            errorDescription: message
        )
    }

    private func finish(_ result: Result<DNSResolutionResult, Error>) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}

private struct HTTPTransactionTiming: Sendable {
    var dnsMilliseconds: Double?
    var connectMilliseconds: Double?
    var tlsMilliseconds: Double?
    var ttfbMilliseconds: Double?
    var totalMilliseconds: Double?
    var redirectCount = 0
    var remoteAddress: String?
    var usedProxy: Bool?
}

private struct HTTPMetricsOutput: Sendable {
    let response: HTTPURLResponse?
    let responseBytes: Int
    let metrics: HTTPTransactionTiming
    let responseTooLarge: Bool
}

private final class HTTPMetricsRequest: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private static let maximumResponseBytes = 65_536

    private let lock = NSLock()
    private var continuation: CheckedContinuation<HTTPMetricsOutput, Error>?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var response: HTTPURLResponse?
    private var responseBytes = 0
    private var timing = HTTPTransactionTiming()
    private var responseTooLarge = false
    private var completed = false
    private var cancellationRequested = false

    static func run(request: URLRequest) async throws -> HTTPMetricsOutput {
        let runner = HTTPMetricsRequest()
        return try await runner.start(request: request)
    }

    private func start(request: URLRequest) async throws -> HTTPMetricsOutput {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let configuration = URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForRequest = 8
                configuration.timeoutIntervalForResource = 10
                configuration.waitsForConnectivity = false
                configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                configuration.httpShouldSetCookies = false
                configuration.httpCookieStorage = nil
                configuration.urlCredentialStorage = nil
                configuration.urlCache = nil
                let session = URLSession(
                    configuration: configuration,
                    delegate: self,
                    delegateQueue: nil
                )
                let task = session.dataTask(with: request)

                lock.lock()
                self.continuation = continuation
                self.session = session
                self.task = task
                let shouldCancel = cancellationRequested
                lock.unlock()
                if shouldCancel {
                    task.cancel()
                } else {
                    task.resume()
                }
            }
        } onCancel: {
            cancel()
        }
    }

    private func cancel() {
        lock.lock()
        cancellationRequested = true
        let task = task
        lock.unlock()
        task?.cancel()
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        lock.lock()
        self.response = response as? HTTPURLResponse
        lock.unlock()
        completionHandler(.allow)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        lock.lock()
        responseBytes += data.count
        if responseBytes > Self.maximumResponseBytes {
            responseTooLarge = true
            lock.unlock()
            dataTask.cancel()
            return
        }
        lock.unlock()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        let transaction = metrics.transactionMetrics.last
        let first = metrics.transactionMetrics.first
        var collected = HTTPTransactionTiming()
        collected.dnsMilliseconds = duration(
            from: transaction?.domainLookupStartDate,
            to: transaction?.domainLookupEndDate
        )
        collected.connectMilliseconds = duration(
            from: transaction?.connectStartDate,
            to: transaction?.connectEndDate
        )
        collected.tlsMilliseconds = duration(
            from: transaction?.secureConnectionStartDate,
            to: transaction?.secureConnectionEndDate
        )
        collected.ttfbMilliseconds = duration(
            from: transaction?.requestStartDate ?? transaction?.fetchStartDate,
            to: transaction?.responseStartDate
        )
        collected.totalMilliseconds = duration(
            from: first?.fetchStartDate ?? metrics.taskInterval.start,
            to: transaction?.responseEndDate ?? metrics.taskInterval.end
        )
        collected.redirectCount = metrics.redirectCount
        collected.remoteAddress = transaction?.remoteAddress
        collected.usedProxy = transaction?.isProxyConnection

        lock.lock()
        timing = collected
        lock.unlock()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        let continuation = continuation
        self.continuation = nil
        let response = response
        let responseBytes = responseBytes
        let timing = timing
        let responseTooLarge = responseTooLarge
        let cancellationRequested = cancellationRequested
        self.session = nil
        self.task = nil
        lock.unlock()

        session.finishTasksAndInvalidate()
        if let error, !(responseTooLarge && response != nil) {
            if (error as NSError).code == NSURLErrorCancelled,
               cancellationRequested {
                continuation?.resume(throwing: CancellationError())
            } else {
                continuation?.resume(throwing: error)
            }
        } else {
            continuation?.resume(returning: HTTPMetricsOutput(
                response: response,
                responseBytes: responseBytes,
                metrics: timing,
                responseTooLarge: responseTooLarge
            ))
        }
    }

    private func duration(from start: Date?, to end: Date?) -> Double? {
        guard let start, let end else { return nil }
        return max(0, end.timeIntervalSince(start) * 1_000)
    }
}

struct LocalNetworkAddress: Identifiable, Equatable, Sendable {
    let id: String
    let interfaceName: String
    let address: String
    let subnetMask: String?
    let ipVersion: String
    let isLoopback: Bool

    var cidrPrefixLength: Int? {
        guard let subnetMask, !subnetMask.isEmpty else { return nil }
        if ipVersion == "IPv4" {
            var parsed = in_addr()
            guard inet_pton(AF_INET, subnetMask, &parsed) == 1 else {
                return nil
            }
            return withUnsafeBytes(of: parsed) { bytes in
                bytes.reduce(0) { $0 + $1.nonzeroBitCount }
            }
        }

        var parsed = in6_addr()
        guard inet_pton(AF_INET6, subnetMask, &parsed) == 1 else {
            return nil
        }
        return withUnsafeBytes(of: parsed) { bytes in
            bytes.reduce(0) { $0 + $1.nonzeroBitCount }
        }
    }
}

struct NetworkProxySnapshot: Equatable, Sendable {
    let httpEnabled: Bool
    let httpsEnabled: Bool
    let socksEnabled: Bool
    let pacEnabled: Bool
    let httpHost: String?
    let httpsHost: String?
    let socksHost: String?
    let pacURL: String?

    var isAnyEnabled: Bool {
        httpEnabled || httpsEnabled || socksEnabled || pacEnabled
    }
}

struct WiFiDetailsSnapshot: Equatable, Sendable {
    let interfaceName: String?
    let powerOn: Bool
    let ssid: String?
    let bssid: String?
    let rssi: Int?
    let noise: Int?
    let channel: Int?
    let band: String?
    let phyMode: String?
    let interfaceMode: String?
    let transmitRateMbps: Double?
    let countryCode: String?
    let privacyRestrictionNote: String?
}

struct LocalNetworkDetailsSnapshot: Equatable, Sendable {
    let capturedAt: Date
    let statusKey: String
    let primaryInterfaceName: String?
    let primaryInterfaceTypeKey: String
    let networkServiceName: String?
    let supportsIPv4: Bool
    let supportsIPv6: Bool
    let supportsDNS: Bool
    let isConstrained: Bool
    let isExpensive: Bool
    let defaultGateway: String?
    let mtu: Int?
    let addresses: [LocalNetworkAddress]
    let macAddress: String?
    let dnsServers: [String]
    let searchDomains: [String]
    let proxy: NetworkProxySnapshot
    let tunnelInterfaces: [String]
    let wifi: WiFiDetailsSnapshot?
}

struct LocalNetworkDetailsReader: Sendable {
    func read() async -> LocalNetworkDetailsSnapshot {
        let path = await OneShotNetworkPathReader.read()
        let dynamic = SystemNetworkConfigurationReader.read()
        let primaryInterface = dynamic.primaryInterface
            ?? activeInterfaceName(path: path)
        let interfaceData = InterfaceAddressReader.read(
            primaryInterface: primaryInterface
        )
        let wifi = WiFiDetailsReader.read(primaryInterface: primaryInterface)

        return LocalNetworkDetailsSnapshot(
            capturedAt: Date(),
            statusKey: path.status == .satisfied ? "网络已连接" : "网络不可用",
            primaryInterfaceName: primaryInterface,
            primaryInterfaceTypeKey: interfaceTypeKey(
                path: path,
                interfaceName: primaryInterface
            ),
            networkServiceName: dynamic.serviceName,
            supportsIPv4: path.supportsIPv4,
            supportsIPv6: path.supportsIPv6,
            supportsDNS: path.supportsDNS,
            isConstrained: path.isConstrained,
            isExpensive: path.isExpensive,
            defaultGateway: dynamic.defaultGateway
                ?? path.gateways.first.map(endpointDescription),
            mtu: interfaceData.mtu,
            addresses: interfaceData.addresses,
            macAddress: interfaceData.macAddress,
            dnsServers: dynamic.dnsServers,
            searchDomains: dynamic.searchDomains,
            proxy: dynamic.proxy,
            tunnelInterfaces: interfaceData.tunnelInterfaces,
            wifi: wifi
        )
    }

    private func activeInterfaceName(path: NWPath) -> String? {
        path.availableInterfaces.first { interface in
            path.usesInterfaceType(interface.type)
        }?.name
    }

    private func interfaceTypeKey(path: NWPath, interfaceName: String?) -> String {
        if let interfaceName,
           InterfaceAddressReader.isTunnelName(interfaceName) {
            return "VPN / 隧道"
        }
        if path.usesInterfaceType(.wifi) { return "Wi‑Fi" }
        if path.usesInterfaceType(.wiredEthernet) { return "Ethernet" }
        if path.usesInterfaceType(.cellular) { return "蜂窝网络" }
        if path.usesInterfaceType(.loopback) { return "回环接口" }
        return "其他网络接口"
    }

    private func endpointDescription(_ endpoint: NWEndpoint) -> String {
        switch endpoint {
        case let .hostPort(host, _):
            return "\(host)"
        default:
            return "\(endpoint)"
        }
    }
}

private final class OneShotNetworkPathReader: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.shixinqvq.xinmai.network-path")
    private let lock = NSLock()
    private var continuation: CheckedContinuation<NWPath, Never>?
    private var finished = false

    static func read() async -> NWPath {
        let reader = OneShotNetworkPathReader()
        return await reader.start()
    }

    private func start() async -> NWPath {
        await withCheckedContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()
            monitor.pathUpdateHandler = { [weak self] path in
                self?.finish(path)
            }
            monitor.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self else { return }
                self.finish(self.monitor.currentPath)
            }
        }
    }

    private func finish(_ path: NWPath) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        monitor.cancel()
        continuation?.resume(returning: path)
    }
}

private struct SystemNetworkConfiguration {
    let primaryInterface: String?
    let defaultGateway: String?
    let serviceName: String?
    let dnsServers: [String]
    let searchDomains: [String]
    let proxy: NetworkProxySnapshot
}

private enum SystemNetworkConfigurationReader {
    static func read() -> SystemNetworkConfiguration {
        let globalIPv4 = SCDynamicStoreCopyValue(
            nil,
            "State:/Network/Global/IPv4" as CFString
        ) as? [String: Any]
        let globalIPv6 = SCDynamicStoreCopyValue(
            nil,
            "State:/Network/Global/IPv6" as CFString
        ) as? [String: Any]
        let globalDNS = SCDynamicStoreCopyValue(
            nil,
            "State:/Network/Global/DNS" as CFString
        ) as? [String: Any]
        let primaryInterface = globalIPv4?["PrimaryInterface"] as? String
            ?? globalIPv6?["PrimaryInterface"] as? String
        let gateway = globalIPv4?["Router"] as? String
            ?? globalIPv6?["Router"] as? String
        let serviceID = globalIPv4?["PrimaryService"] as? String
            ?? globalIPv6?["PrimaryService"] as? String
        let serviceName = serviceID.flatMap(networkServiceName)
        let proxyDictionary = SCDynamicStoreCopyProxies(nil) as? [String: Any] ?? [:]

        return SystemNetworkConfiguration(
            primaryInterface: primaryInterface,
            defaultGateway: gateway,
            serviceName: serviceName,
            dnsServers: globalDNS?["ServerAddresses"] as? [String] ?? [],
            searchDomains: globalDNS?["SearchDomains"] as? [String] ?? [],
            proxy: NetworkProxySnapshot(
                httpEnabled: enabled(proxyDictionary[kSCPropNetProxiesHTTPEnable as String]),
                httpsEnabled: enabled(proxyDictionary[kSCPropNetProxiesHTTPSEnable as String]),
                socksEnabled: enabled(proxyDictionary[kSCPropNetProxiesSOCKSEnable as String]),
                pacEnabled: enabled(
                    proxyDictionary[kSCPropNetProxiesProxyAutoConfigEnable as String]
                ),
                httpHost: proxyDictionary[kSCPropNetProxiesHTTPProxy as String] as? String,
                httpsHost: proxyDictionary[kSCPropNetProxiesHTTPSProxy as String] as? String,
                socksHost: proxyDictionary[kSCPropNetProxiesSOCKSProxy as String] as? String,
                pacURL: proxyDictionary[
                    kSCPropNetProxiesProxyAutoConfigURLString as String
                ] as? String
            )
        )
    }

    private static func enabled(_ value: Any?) -> Bool {
        (value as? NSNumber)?.boolValue == true
    }

    private static func networkServiceName(serviceID: String) -> String? {
        guard let preferences = SCPreferencesCreate(
            nil,
            "SHIXIN LAB XinMai" as CFString,
            nil
        ),
        let service = SCNetworkServiceCopy(preferences, serviceID as CFString) else {
            return nil
        }
        return SCNetworkServiceGetName(service) as String?
    }
}

private struct InterfaceAddressSnapshot {
    let addresses: [LocalNetworkAddress]
    let macAddress: String?
    let mtu: Int?
    let tunnelInterfaces: [String]
}

private enum InterfaceAddressReader {
    static func read(primaryInterface: String?) -> InterfaceAddressSnapshot {
        var addressList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressList) == 0, let addressList else {
            return InterfaceAddressSnapshot(
                addresses: [],
                macAddress: nil,
                mtu: nil,
                tunnelInterfaces: []
            )
        }
        defer { freeifaddrs(addressList) }

        var addresses: [LocalNetworkAddress] = []
        var primaryMAC: String?
        var primaryMTU: Int?
        var tunnelNames = Set<String>()
        var cursor: UnsafeMutablePointer<ifaddrs>? = addressList

        while let current = cursor {
            cursor = current.pointee.ifa_next
            let name = String(cString: current.pointee.ifa_name)
            if isTunnelName(name) {
                tunnelNames.insert(name)
            }
            guard let address = current.pointee.ifa_addr else { continue }
            let family = Int32(address.pointee.sa_family)

            if family == AF_INET || family == AF_INET6 {
                guard let host = numericAddress(address) else { continue }
                let mask = numericAddress(current.pointee.ifa_netmask)
                let isLoopback = (current.pointee.ifa_flags & UInt32(IFF_LOOPBACK)) != 0
                addresses.append(LocalNetworkAddress(
                    id: "\(name)-\(host)",
                    interfaceName: name,
                    address: host,
                    subnetMask: mask,
                    ipVersion: family == AF_INET ? "IPv4" : "IPv6",
                    isLoopback: isLoopback
                ))
            } else if family == AF_LINK, name == primaryInterface {
                primaryMAC = macAddress(address)
                if let data = current.pointee.ifa_data {
                    primaryMTU = Int(
                        data.assumingMemoryBound(to: if_data.self).pointee.ifi_mtu
                    )
                }
            }
        }

        addresses.sort {
            if $0.interfaceName != $1.interfaceName {
                return $0.interfaceName < $1.interfaceName
            }
            return $0.ipVersion < $1.ipVersion
        }
        return InterfaceAddressSnapshot(
            addresses: addresses,
            macAddress: primaryMAC,
            mtu: primaryMTU,
            tunnelInterfaces: tunnelNames.sorted()
        )
    }

    static func isTunnelName(_ name: String) -> Bool {
        ["utun", "ppp", "ipsec", "tun", "tap"].contains {
            name.lowercased().hasPrefix($0)
        }
    }

    private static func numericAddress(_ address: UnsafePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let length = socklen_t(address.pointee.sa_len)
        guard getnameinfo(
            address,
            length,
            &host,
            socklen_t(host.count),
            nil,
            0,
            NI_NUMERICHOST
        ) == 0 else {
            return nil
        }
        return String(cString: host)
    }

    private static func macAddress(_ address: UnsafePointer<sockaddr>) -> String? {
        let link = UnsafeRawPointer(address)
            .assumingMemoryBound(to: sockaddr_dl.self)
        let addressLength = Int(link.pointee.sdl_alen)
        let nameLength = Int(link.pointee.sdl_nlen)
        guard addressLength > 0,
              let dataOffset = MemoryLayout<sockaddr_dl>.offset(of: \.sdl_data) else {
            return nil
        }
        let bytes = UnsafeRawPointer(address)
            .advanced(by: dataOffset + nameLength)
            .assumingMemoryBound(to: UInt8.self)
        return (0..<addressLength)
            .map { String(format: "%02X", bytes[$0]) }
            .joined(separator: ":")
    }
}

private enum WiFiDetailsReader {
    static func read(primaryInterface: String?) -> WiFiDetailsSnapshot? {
        let client = CWWiFiClient.shared()
        let interface = client.interface(withName: primaryInterface)
            ?? client.interface()
        guard let interface else { return nil }
        let channel = interface.wlanChannel()
        let ssid = interface.ssid()
        let bssid = interface.bssid()
        let restriction: String? = (ssid == nil || bssid == nil)
            ? "SSID、BSSID 与国家代码需要开启定位服务并授权；未授权时系统不会提供。"
            : nil
        let rssi = interface.rssiValue()
        let noise = interface.noiseMeasurement()
        let transmitRate = interface.transmitRate()

        return WiFiDetailsSnapshot(
            interfaceName: interface.interfaceName,
            powerOn: interface.powerOn(),
            ssid: ssid,
            bssid: bssid,
            rssi: rssi == 0 ? nil : rssi,
            noise: noise == 0 ? nil : noise,
            channel: channel.map { Int($0.channelNumber) },
            band: channel.map { bandName(rawValue: Int($0.channelBand.rawValue)) },
            phyMode: phyModeName(rawValue: Int(interface.activePHYMode().rawValue)),
            interfaceMode: interfaceModeName(
                rawValue: Int(interface.interfaceMode().rawValue)
            ),
            transmitRateMbps: transmitRate > 0 ? transmitRate : nil,
            countryCode: interface.countryCode(),
            privacyRestrictionNote: restriction
        )
    }

    private static func bandName(rawValue: Int) -> String {
        switch rawValue {
        case 1: "2.4 GHz"
        case 2: "5 GHz"
        case 3: "6 GHz"
        default: "—"
        }
    }

    private static func phyModeName(rawValue: Int) -> String? {
        switch rawValue {
        case 1: "802.11a"
        case 2: "802.11b"
        case 3: "802.11g"
        case 4: "Wi‑Fi 4 · 802.11n"
        case 5: "Wi‑Fi 5 · 802.11ac"
        case 6: "Wi‑Fi 6/6E · 802.11ax"
        case 7: "Wi‑Fi 7 · 802.11be"
        default: nil
        }
    }

    private static func interfaceModeName(rawValue: Int) -> String? {
        switch rawValue {
        case 1: "Station"
        case 2: "IBSS"
        case 3: "Host AP"
        default: nil
        }
    }
}

struct PublicNetworkIntelligenceSnapshot: Equatable, Sendable {
    let checkedAt: Date
    let ipv4Address: String?
    let ipv6Address: String?
    let ipv4Profile: PublicIPProfile?
    let ipv6Profile: PublicIPProfile?
    let riskProfile: IPRiskProfile?
    let providerErrors: [String]

    var preferredProfile: PublicIPProfile? {
        ipv4Profile ?? ipv6Profile
    }

    var hasProviderFailure: Bool {
        preferredProfile == nil || riskProfile == nil
    }

    var historySummary: PublicNetworkHistorySummary {
        PublicNetworkHistorySummary(
            countryCode: preferredProfile?.countryCode,
            asn: preferredProfile?.asn ?? riskProfile?.asn,
            networkType: riskProfile?.networkType,
            sources: Array(
                Set(
                    [
                        preferredProfile?.source,
                        riskProfile?.source,
                        "ipify"
                    ].compactMap { $0 }
                )
            ).sorted()
        )
    }
}

struct PublicNetworkIntelligenceService: Sendable {
    func query() async -> PublicNetworkIntelligenceSnapshot {
        async let ipv4Result = requestIPAddress(
            URL(string: "https://api.ipify.org?format=json")!
        )
        async let ipv6Result = requestIPAddress(
            URL(string: "https://api6.ipify.org?format=json")!
        )

        let ipv4 = await ipv4Result
        let ipv6 = await ipv6Result
        async let ipv4ProfileResult = requestProfile(ip: ipv4.value)
        async let ipv6ProfileResult = requestProfile(ip: ipv6.value)
        async let riskResult = requestRisk(ip: ipv4.value ?? ipv6.value)
        let v4Profile = await ipv4ProfileResult
        let v6Profile = await ipv6ProfileResult
        let risk = await riskResult

        return PublicNetworkIntelligenceSnapshot(
            checkedAt: Date(),
            ipv4Address: ipv4.value,
            ipv6Address: ipv6.value,
            ipv4Profile: v4Profile.value,
            ipv6Profile: v6Profile.value,
            riskProfile: risk.value,
            providerErrors: [
                ipv4.error,
                ipv6.error,
                v4Profile.error,
                v6Profile.error,
                risk.error
            ].compactMap { $0 }
        )
    }

    private func requestIPAddress(_ url: URL) async -> ProviderResult<String> {
        do {
            let data = try await request(url: url, maximumBytes: 4_096)
            if let object = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any],
               let ip = object["ip"] as? String,
               !ip.isEmpty {
                return ProviderResult(value: ip, error: nil)
            }
            let text = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, text.count <= 64 else {
                return ProviderResult(value: nil, error: "ipify：结果不可解析")
            }
            return ProviderResult(value: text, error: nil)
        } catch {
            return ProviderResult(
                value: nil,
                error: "ipify：\(safeProviderError(error))"
            )
        }
    }

    private func requestProfile(ip: String?) async -> ProviderResult<PublicIPProfile> {
        guard let ip else { return ProviderResult(value: nil, error: nil) }
        guard let encodedIP = ip.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ),
        let url = URL(string: "https://ipwho.is/\(encodedIP)") else {
            return ProviderResult(value: nil, error: "ipwho.is：IP 格式无效")
        }
        do {
            let data = try await request(url: url, maximumBytes: 32_768)
            return ProviderResult(
                value: try IPWhoIsParser.parse(data: data),
                error: nil
            )
        } catch {
            return ProviderResult(
                value: nil,
                error: "ipwho.is：\(safeProviderError(error))"
            )
        }
    }

    private func requestRisk(ip: String?) async -> ProviderResult<IPRiskProfile> {
        guard let ip else { return ProviderResult(value: nil, error: nil) }
        guard let encodedIP = ip.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ),
        let url = URL(
            string: "https://proxycheck.io/v3/\(encodedIP)?tag=0&p=0&risk=2&ver=24-June-2026"
        ) else {
            return ProviderResult(value: nil, error: "proxycheck.io：IP 格式无效")
        }
        do {
            let data = try await request(url: url, maximumBytes: 65_536)
            return ProviderResult(
                value: try ProxyCheckParser.parse(data: data, queriedIP: ip),
                error: nil
            )
        } catch {
            return ProviderResult(
                value: nil,
                error: "proxycheck.io：\(safeProviderError(error))"
            )
        }
    }

    private func request(url: URL, maximumBytes: Int) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json,text/plain", forHTTPHeaderField: "Accept")
        request.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue(
            "SHIXIN-LAB-XinMai-Network-Details/0.3",
            forHTTPHeaderField: "User-Agent"
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 10
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard data.count <= maximumBytes else {
            throw URLError(.dataLengthExceedsMaximum)
        }
        return data
    }

    private func safeProviderError(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain) \(nsError.code)"
    }
}

private struct ProviderResult<Value: Sendable>: Sendable {
    let value: Value?
    let error: String?
}

enum NetworkPrivacyInputBuilder {
    static func make(
        local: LocalNetworkDetailsSnapshot?,
        publicSnapshot: PublicNetworkIntelligenceSnapshot?
    ) -> PrivacyConsistencyInput? {
        guard let local, let publicSnapshot else { return nil }
        let v4 = publicSnapshot.ipv4Profile
        let v6 = publicSnapshot.ipv6Profile
        let countryMismatch: Bool? = {
            guard let v4Country = v4?.countryCode,
                  let v6Country = v6?.countryCode else {
                return nil
            }
            return v4Country.caseInsensitiveCompare(v6Country) != .orderedSame
        }()
        let hasRoutePrivacyTool = local.proxy.isAnyEnabled
            || !local.tunnelInterfaces.isEmpty
        let possibleBypass = countryMismatch.map {
            $0 && hasRoutePrivacyTool
        }
        return PrivacyConsistencyInput(
            ipv4CountryCode: v4?.countryCode,
            ipv6CountryCode: v6?.countryCode,
            ipv4ASN: v4?.asn,
            ipv6ASN: v6?.asn,
            publicEndpointAgreement: nil,
            timeZoneMatchesExit: timeZoneMatches(
                localTimeZone: TimeZone.current.identifier,
                exitTimeZone: publicSnapshot.preferredProfile?.timezoneIdentifier
            ),
            localeMatchesExit: localeMatches(
                localeRegion: Locale.current.region?.identifier,
                exitCountry: publicSnapshot.preferredProfile?.countryCode
            ),
            proxyEnabled: local.proxy.isAnyEnabled,
            tunnelInterfaceCount: local.tunnelInterfaces.count,
            primaryInterfaceIsTunnel: local.primaryInterfaceName.map(
                InterfaceAddressReader.isTunnelName
            ) ?? false,
            possibleIPv6Bypass: possibleBypass,
            dnsLeakVerified: nil,
            webRTCLeakVerified: nil
        )
    }

    private static func timeZoneMatches(
        localTimeZone: String,
        exitTimeZone: String?
    ) -> Bool? {
        guard let local = TimeZone(identifier: localTimeZone),
              let exitTimeZone,
              let exit = TimeZone(identifier: exitTimeZone) else {
            return nil
        }
        let now = Date()
        return local.secondsFromGMT(for: now) == exit.secondsFromGMT(for: now)
    }

    private static func localeMatches(
        localeRegion: String?,
        exitCountry: String?
    ) -> Bool? {
        guard let localeRegion, let exitCountry else { return nil }
        return localeRegion.caseInsensitiveCompare(exitCountry) == .orderedSame
    }
}

enum NetworkDetailsPhase: Equatable {
    case idle
    case loadingLocal
    case localReady
    case queryingPublic
    case ready
    case failed

    var isLoading: Bool {
        self == .loadingLocal || self == .queryingPublic
    }
}

@MainActor
final class NetworkLocationAuthorizationController: NSObject, ObservableObject {
    @Published private(set) var status: CLAuthorizationStatus

    private let manager: CLLocationManager

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    func requestIfNeeded() {
        status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }
}

extension NetworkLocationAuthorizationController: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        let newStatus = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.status = newStatus
        }
    }
}

@MainActor
final class NetworkDetailsController: ObservableObject {
    @Published private(set) var phase: NetworkDetailsPhase = .idle
    @Published private(set) var localSnapshot: LocalNetworkDetailsSnapshot?
    @Published private(set) var publicSnapshot: PublicNetworkIntelligenceSnapshot?
    @Published private(set) var reputationAssessment: ScoreAssessment?
    @Published private(set) var privacyAssessment: ScoreAssessment?
    @Published private(set) var combinedAssessment: ScoreAssessment?
    @Published private(set) var errorMessage: String?
    @Published var showsSensitiveInformation = false

    private let localReader = LocalNetworkDetailsReader()
    private let intelligenceService = PublicNetworkIntelligenceService()
    private var localTask: Task<Void, Never>?
    private var publicTask: Task<Void, Never>?
    private var localGeneration: UInt64 = 0
    private var publicGeneration: UInt64 = 0

    func loadLocal() {
        guard localTask == nil else { return }
        localGeneration &+= 1
        let generation = localGeneration
        phase = .loadingLocal
        errorMessage = nil
        localTask = Task { [weak self] in
            guard let self else { return }
            let snapshot = await localReader.read()
            guard !Task.isCancelled,
                  generation == localGeneration else { return }
            localSnapshot = snapshot
            phase = .localReady
            localTask = nil
        }
    }

    func refreshLocal() {
        localGeneration &+= 1
        localTask?.cancel()
        localTask = nil
        loadLocal()
    }

    func queryPublicAndReputation() {
        guard publicTask == nil else { return }
        publicGeneration &+= 1
        let generation = publicGeneration
        let localGenerationAtStart = localGeneration
        phase = .queryingPublic
        errorMessage = nil
        publicTask = Task { [weak self] in
            guard let self else { return }
            if localSnapshot == nil {
                let snapshot = await localReader.read()
                guard !Task.isCancelled,
                      generation == publicGeneration else { return }
                if localGenerationAtStart == localGeneration {
                    localSnapshot = snapshot
                }
            }
            let snapshot = await intelligenceService.query()
            guard !Task.isCancelled,
                  generation == publicGeneration else { return }
            publicSnapshot = snapshot
            reputationAssessment = IPReputationAssessmentEngine.assess(snapshot.riskProfile)
            privacyAssessment = PrivacyConsistencyAssessmentEngine.assess(
                NetworkPrivacyInputBuilder.make(
                    local: localSnapshot,
                    publicSnapshot: snapshot
                )
            )
            combinedAssessment = CombinedNetworkAssessmentEngine.assess(
                international: nil,
                reputation: reputationAssessment,
                privacy: privacyAssessment
            )
            if snapshot.preferredProfile == nil && snapshot.riskProfile == nil {
                phase = .failed
                errorMessage = "公网与信誉服务暂时不可用，本机网络详情仍可查看。"
            } else {
                phase = .ready
                if !snapshot.providerErrors.isEmpty {
                    errorMessage = "部分外部数据源不可用，已按现有数据降低置信度。"
                }
            }
            if generation == publicGeneration {
                publicTask = nil
            }
        }
    }

    func cancel() {
        localGeneration &+= 1
        publicGeneration &+= 1
        localTask?.cancel()
        publicTask?.cancel()
        localTask = nil
        publicTask = nil
    }
}
