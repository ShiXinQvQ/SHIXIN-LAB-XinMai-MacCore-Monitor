// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// This module is intentionally separate from ShixinStressPowerCore so the
// privileged Helper never links network-diagnostics models or provider data.

public enum InternationalTargetID: String, Codable, CaseIterable, Identifiable, Sendable {
    case google
    case youtube
    case x
    case instagram
    case github

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .google: "Google"
        case .youtube: "YouTube"
        case .x: "X / Twitter"
        case .instagram: "Instagram"
        case .github: "GitHub"
        }
    }

    public var host: String {
        switch self {
        case .google: "www.google.com"
        case .youtube: "www.youtube.com"
        case .x: "x.com"
        case .instagram: "www.instagram.com"
        case .github: "github.com"
        }
    }
}

public enum InternationalProbeErrorKind: String, Codable, Equatable, Sendable {
    case dnsFailure
    case timeout
    case offline
    case connectionReset
    case connectionFailure
    case tlsFailure
    case httpAbnormal
    case cancelled
    case responseTooLarge
    case unknown
}

public struct InternationalProbeAttempt: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let dnsMilliseconds: Double?
    public let connectMilliseconds: Double?
    public let tlsMilliseconds: Double?
    public let ttfbMilliseconds: Double?
    public let totalMilliseconds: Double?
    public let statusCode: Int?
    public let responseBytes: Int
    public let finalHost: String?
    public let redirectCount: Int
    public let resolvedIPv4: Bool
    public let resolvedIPv6: Bool
    public let usedIPVersion: String?
    public let usedProxy: Bool?
    public let errorKind: InternationalProbeErrorKind?
    public let errorDescription: String?

    public init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        dnsMilliseconds: Double?,
        connectMilliseconds: Double?,
        tlsMilliseconds: Double?,
        ttfbMilliseconds: Double?,
        totalMilliseconds: Double?,
        statusCode: Int?,
        responseBytes: Int = 0,
        finalHost: String?,
        redirectCount: Int = 0,
        resolvedIPv4: Bool,
        resolvedIPv6: Bool,
        usedIPVersion: String?,
        usedProxy: Bool?,
        errorKind: InternationalProbeErrorKind?,
        errorDescription: String?
    ) {
        self.id = id
        self.startedAt = startedAt
        self.dnsMilliseconds = dnsMilliseconds
        self.connectMilliseconds = connectMilliseconds
        self.tlsMilliseconds = tlsMilliseconds
        self.ttfbMilliseconds = ttfbMilliseconds
        self.totalMilliseconds = totalMilliseconds
        self.statusCode = statusCode
        self.responseBytes = responseBytes
        self.finalHost = finalHost
        self.redirectCount = redirectCount
        self.resolvedIPv4 = resolvedIPv4
        self.resolvedIPv6 = resolvedIPv6
        self.usedIPVersion = usedIPVersion
        self.usedProxy = usedProxy
        self.errorKind = errorKind
        self.errorDescription = errorDescription
    }

    public var dnsSucceeded: Bool {
        resolvedIPv4 || resolvedIPv6
    }

    public var tcpSucceeded: Bool {
        connectMilliseconds != nil || statusCode != nil
    }

    public var tlsSucceeded: Bool {
        tlsMilliseconds != nil || statusCode != nil
    }

    public var httpSucceeded: Bool {
        guard let statusCode else { return false }
        return (200..<400).contains(statusCode)
    }

    public var serviceResponded: Bool {
        statusCode != nil
    }
}

public enum InternationalTargetStatus: String, Codable, Equatable, Sendable {
    case good
    case slow
    case partial
    case unavailable
    case insufficient

    public var titleKey: String {
        switch self {
        case .good: "连接良好"
        case .slow: "可访问但较慢"
        case .partial: "部分异常"
        case .unavailable: "无法访问"
        case .insufficient: "数据不足"
        }
    }
}

public struct InternationalTargetResult: Codable, Equatable, Identifiable, Sendable {
    public let id: InternationalTargetID
    public let requestedHost: String
    public let requestedAttemptCount: Int
    public let attempts: [InternationalProbeAttempt]

    public init(
        id: InternationalTargetID,
        requestedHost: String? = nil,
        requestedAttemptCount: Int = 3,
        attempts: [InternationalProbeAttempt]
    ) {
        self.id = id
        self.requestedHost = requestedHost ?? id.host
        self.requestedAttemptCount = max(1, requestedAttemptCount)
        self.attempts = attempts
    }

    public var successfulAttempts: [InternationalProbeAttempt] {
        attempts.filter(\.httpSucceeded)
    }

    public var averageTotalMilliseconds: Double? {
        Self.average(successfulAttempts.compactMap(\.totalMilliseconds))
    }

    public var averageDNSMilliseconds: Double? {
        Self.average(attempts.compactMap(\.dnsMilliseconds))
    }

    public var averageConnectMilliseconds: Double? {
        Self.average(attempts.compactMap(\.connectMilliseconds))
    }

    public var averageTLSMilliseconds: Double? {
        Self.average(attempts.compactMap(\.tlsMilliseconds))
    }

    public var averageTTFBMilliseconds: Double? {
        Self.average(attempts.compactMap(\.ttfbMilliseconds))
    }

    public var jitterMilliseconds: Double? {
        let values = successfulAttempts.compactMap(\.totalMilliseconds)
        guard values.count >= 2 else { return nil }
        let differences = zip(values.dropFirst(), values).map { abs($0 - $1) }
        return Self.average(differences)
    }

    public var resolvedIPv4: Bool {
        attempts.contains(where: \.resolvedIPv4)
    }

    public var resolvedIPv6: Bool {
        attempts.contains(where: \.resolvedIPv6)
    }

    public var finalHost: String? {
        attempts.compactMap(\.finalHost).last
    }

    public var redirectCount: Int {
        attempts.map(\.redirectCount).max() ?? 0
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

public struct InternationalOperationalAssessments: Equatable, Sendable {
    public let protocolSuccess: ScoreAssessment
    public let latencyQuality: ScoreAssessment
    public let connectionStability: ScoreAssessment
    public let addressFamilyCoverage: ScoreAssessment

    public init(
        protocolSuccess: ScoreAssessment,
        latencyQuality: ScoreAssessment,
        connectionStability: ScoreAssessment,
        addressFamilyCoverage: ScoreAssessment
    ) {
        self.protocolSuccess = protocolSuccess
        self.latencyQuality = latencyQuality
        self.connectionStability = connectionStability
        self.addressFamilyCoverage = addressFamilyCoverage
    }
}

public enum AssessmentImpact: String, Codable, Equatable, Sendable {
    case positive
    case informational
    case caution
    case risk
    case unavailable
}

public struct AssessmentSignal: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let titleKey: String
    public let detailKey: String
    public let impact: AssessmentImpact
    public let scoreDelta: Int

    public init(
        id: String,
        titleKey: String,
        detailKey: String,
        impact: AssessmentImpact,
        scoreDelta: Int = 0
    ) {
        self.id = id
        self.titleKey = titleKey
        self.detailKey = detailKey
        self.impact = impact
        self.scoreDelta = scoreDelta
    }
}

public enum AssessmentGrade: String, Codable, Equatable, Sendable {
    case excellent
    case good
    case fair
    case poor
    case risk
    case insufficient

    public var titleKey: String {
        switch self {
        case .excellent: "极佳"
        case .good: "良好"
        case .fair: "一般"
        case .poor: "较差"
        case .risk: "存在风险信号"
        case .insufficient: "数据不足"
        }
    }
}

public struct ScoreAssessment: Codable, Equatable, Sendable {
    public let score: Int?
    public let grade: AssessmentGrade
    public let completeness: Double
    public let confidence: Double
    public let signals: [AssessmentSignal]

    public init(
        score: Int?,
        grade: AssessmentGrade? = nil,
        completeness: Double,
        confidence: Double,
        signals: [AssessmentSignal]
    ) {
        let clampedScore = score.map { min(100, max(0, $0)) }
        self.score = clampedScore
        self.grade = grade ?? Self.grade(for: clampedScore)
        self.completeness = min(1, max(0, completeness))
        self.confidence = min(1, max(0, confidence))
        self.signals = signals
    }

    public static func grade(for score: Int?) -> AssessmentGrade {
        guard let score else { return .insufficient }
        switch score {
        case 90...: return .excellent
        case 75..<90: return .good
        case 60..<75: return .fair
        case 40..<60: return .poor
        default: return .risk
        }
    }
}

public enum InternationalOperationalAssessmentEngine {
    public static func assess(
        _ results: [InternationalTargetResult]
    ) -> InternationalOperationalAssessments {
        InternationalOperationalAssessments(
            protocolSuccess: protocolAssessment(results),
            latencyQuality: latencyAssessment(results),
            connectionStability: stabilityAssessment(results),
            addressFamilyCoverage: addressFamilyAssessment(results)
        )
    }

    private static func protocolAssessment(
        _ results: [InternationalTargetResult]
    ) -> ScoreAssessment {
        let requestedAttempts = results.reduce(0) {
            $0 + $1.requestedAttemptCount
        }
        let expectedStages = requestedAttempts * 4
        let completedAttempts = results.reduce(0) {
            $0 + $1.attempts.count
        }
        let successfulStages = results
            .flatMap(\.attempts)
            .reduce(0) { partial, attempt in
                partial
                    + (attempt.dnsSucceeded ? 1 : 0)
                    + (attempt.tcpSucceeded ? 1 : 0)
                    + (attempt.tlsSucceeded ? 1 : 0)
                    + (attempt.httpSucceeded ? 1 : 0)
            }
        guard expectedStages > 0 else {
            return missingAssessment(
                title: "尚无协议阶段数据",
                detail: "开始国际网络诊断后，将统计 DNS、TCP、TLS 与 HTTP 四个阶段。"
            )
        }
        let score = Int(
            (Double(successfulStages) / Double(expectedStages) * 100).rounded()
        )
        let completeness = min(
            1,
            Double(completedAttempts) / Double(requestedAttempts)
        )
        return ScoreAssessment(
            score: score,
            completeness: completeness,
            confidence: completeness,
            signals: [
                AssessmentSignal(
                    id: "operational.protocol",
                    titleKey: "协议阶段成功情况",
                    detailKey: "按本轮计划请求逐项统计 DNS、TCP、TLS 与 HTTP，缺失请求不会被当作成功。",
                    impact: score >= 90 ? .positive : (score >= 70 ? .caution : .risk)
                )
            ]
        )
    }

    private static func latencyAssessment(
        _ results: [InternationalTargetResult]
    ) -> ScoreAssessment {
        let requestedAttempts = results.reduce(0) {
            $0 + $1.requestedAttemptCount
        }
        let values = results
            .flatMap(\.successfulAttempts)
            .compactMap(\.totalMilliseconds)
        guard !values.isEmpty, requestedAttempts > 0 else {
            return missingAssessment(
                title: "尚无有效响应耗时",
                detail: "只有获得有效 HTTP 响应后才评估响应速度。"
            )
        }
        let average = values.reduce(0, +) / Double(values.count)
        let score = latencyScore(average)
        let coverage = min(
            1,
            Double(values.count) / Double(requestedAttempts)
        )
        return ScoreAssessment(
            score: score,
            completeness: coverage,
            confidence: coverage,
            signals: [
                AssessmentSignal(
                    id: "operational.latency",
                    titleKey: "完整响应耗时",
                    detailKey: "使用有效请求的完整响应平均值分段评分；100 ms 内为最佳区间，超过 1 秒会明显降低分数。",
                    impact: score >= 90 ? .positive : (score >= 65 ? .caution : .risk)
                )
            ]
        )
    }

    private static func stabilityAssessment(
        _ results: [InternationalTargetResult]
    ) -> ScoreAssessment {
        let values = results.compactMap(\.jitterMilliseconds)
        guard !values.isEmpty, !results.isEmpty else {
            return missingAssessment(
                title: "尚无足够波动样本",
                detail: "每个目标至少需要两次有效响应才能计算连接稳定度。"
            )
        }
        let average = values.reduce(0, +) / Double(values.count)
        let score = stabilityScore(average)
        let coverage = Double(values.count) / Double(results.count)
        return ScoreAssessment(
            score: score,
            completeness: coverage,
            confidence: min(1, coverage * 0.9 + 0.1),
            signals: [
                AssessmentSignal(
                    id: "operational.stability",
                    titleKey: "多目标延迟波动",
                    detailKey: "根据各目标连续有效响应的平均波动评分；10 ms 内最稳定，波动越大分数越低。",
                    impact: score >= 90 ? .positive : (score >= 65 ? .caution : .risk)
                )
            ]
        )
    }

    private static func addressFamilyAssessment(
        _ results: [InternationalTargetResult]
    ) -> ScoreAssessment {
        guard !results.isEmpty else {
            return missingAssessment(
                title: "尚无地址族数据",
                detail: "诊断后将统计各目标的 IPv4 与 IPv6 解析覆盖。"
            )
        }
        let completed = results.filter { !$0.attempts.isEmpty }
        guard !completed.isEmpty else {
            return missingAssessment(
                title: "尚无地址族数据",
                detail: "诊断后将统计各目标的 IPv4 与 IPv6 解析覆盖。"
            )
        }
        let ipv4Count = completed.filter(\.resolvedIPv4).count
        let ipv6Count = completed.filter(\.resolvedIPv6).count
        let score = Int(
            (
                Double(ipv4Count + ipv6Count)
                    / Double(results.count * 2)
                    * 100
            ).rounded()
        )
        let completeness = Double(completed.count) / Double(results.count)
        return ScoreAssessment(
            score: score,
            completeness: completeness,
            confidence: completeness,
            signals: [
                AssessmentSignal(
                    id: "operational.address-family",
                    titleKey: "IPv4 与 IPv6 覆盖",
                    detailKey: "分别统计五个目标是否解析到 IPv4 与 IPv6；这是地址族覆盖，不等同于实际流量一定走双栈。",
                    impact: score >= 90 ? .positive : (score >= 50 ? .informational : .caution)
                )
            ]
        )
    }

    private static func missingAssessment(
        title: String,
        detail: String
    ) -> ScoreAssessment {
        ScoreAssessment(
            score: nil,
            completeness: 0,
            confidence: 0,
            signals: [
                AssessmentSignal(
                    id: "operational.missing.\(title)",
                    titleKey: title,
                    detailKey: detail,
                    impact: .unavailable
                )
            ]
        )
    }

    private static func latencyScore(_ milliseconds: Double) -> Int {
        let score: Double
        switch milliseconds {
        case ...100:
            score = 100
        case ...250:
            score = 100 - (milliseconds - 100) / 150 * 20
        case ...500:
            score = 80 - (milliseconds - 250) / 250 * 20
        case ...1_000:
            score = 60 - (milliseconds - 500) / 500 * 25
        default:
            score = max(5, 35 - (milliseconds - 1_000) / 2_000 * 30)
        }
        return Int(min(100, max(0, score)).rounded())
    }

    private static func stabilityScore(_ milliseconds: Double) -> Int {
        let score: Double
        switch milliseconds {
        case ...10:
            score = 100
        case ...30:
            score = 100 - (milliseconds - 10) / 20 * 15
        case ...80:
            score = 85 - (milliseconds - 30) / 50 * 30
        case ...200:
            score = 55 - (milliseconds - 80) / 120 * 35
        default:
            score = max(0, 20 - (milliseconds - 200) / 300 * 20)
        }
        return Int(min(100, max(0, score)).rounded())
    }
}

public enum InternationalAssessmentEngine {
    public static func targetStatus(_ result: InternationalTargetResult) -> InternationalTargetStatus {
        guard !result.attempts.isEmpty else { return .insufficient }
        let successful = result.successfulAttempts.count
        let abnormalHTTP = result.attempts.contains {
            guard let statusCode = $0.statusCode else { return false }
            return !(200..<400).contains(statusCode)
        }

        if successful >= 2 {
            if result.attempts.count < result.requestedAttemptCount {
                return .partial
            }
            let average = result.averageTotalMilliseconds ?? .infinity
            let jitter = result.jitterMilliseconds ?? .infinity
            return average <= 2_000 && jitter <= 350 ? .good : .slow
        }
        if successful == 1 || abnormalHTTP {
            return .partial
        }
        if result.attempts.allSatisfy({ $0.errorKind == .cancelled }) {
            return .insufficient
        }
        return .unavailable
    }

    public static func assess(_ results: [InternationalTargetResult]) -> ScoreAssessment {
        guard !results.isEmpty else {
            return ScoreAssessment(
                score: nil,
                completeness: 0,
                confidence: 0,
                signals: [
                    AssessmentSignal(
                        id: "international.missing",
                        titleKey: "尚无国际诊断数据",
                        detailKey: "请主动开始一次国际网络诊断。",
                        impact: .unavailable
                    )
                ]
            )
        }

        var scoreTotal = 0.0
        var observedWeightTotal = 0.0
        var maximumWeightTotal = 0.0
        var completedAttempts = 0
        var requestedAttempts = 0
        var signals: [AssessmentSignal] = []

        for result in results {
            let status = targetStatus(result)
            let target = scoreTarget(result)
            scoreTotal += target.score
            observedWeightTotal += target.observedWeight
            maximumWeightTotal += 100
            completedAttempts += result.attempts.count
            requestedAttempts += result.requestedAttemptCount

            let signalImpact: AssessmentImpact
            let detailKey: String
            switch status {
            case .good:
                signalImpact = .positive
                detailKey = "DNS、连接、TLS 与 HTTP 均获得有效结果。"
            case .slow:
                signalImpact = .caution
                detailKey = "目标可以访问，但响应时间或波动偏高。"
            case .partial:
                signalImpact = .caution
                detailKey = "目标有响应，但部分请求或连接阶段异常。"
            case .unavailable:
                signalImpact = .risk
                detailKey = "当前未获得该目标的有效 HTTP 响应。"
            case .insufficient:
                signalImpact = .unavailable
                detailKey = "该目标没有足够数据形成结论。"
            }
            signals.append(
                AssessmentSignal(
                    id: "international.target.\(result.id.rawValue)",
                    titleKey: "\(result.id.displayName)：\(status.titleKey)",
                    detailKey: detailKey,
                    impact: signalImpact
                )
            )
        }

        let completeness = maximumWeightTotal > 0
            ? observedWeightTotal / maximumWeightTotal
            : 0
        let attemptCoverage = requestedAttempts > 0
            ? Double(completedAttempts) / Double(requestedAttempts)
            : 0
        let confidence = min(1, completeness * 0.7 + attemptCoverage * 0.3)
        guard completeness >= 0.4 else {
            return ScoreAssessment(
                score: nil,
                completeness: completeness,
                confidence: confidence,
                signals: signals + [
                    AssessmentSignal(
                        id: "international.incomplete",
                        titleKey: "数据完整度不足",
                        detailKey: "不会用缺失数据推算满分，请检查网络后重试。",
                        impact: .unavailable
                    )
                ]
            )
        }

        let rawScore = scoreTotal / Double(results.count)
        let missingDataFactor = 0.84 + completeness * 0.16
        var finalScore = Int((rawScore * missingDataFactor).rounded())
        if completeness < 0.999 {
            finalScore = min(finalScore, 96)
        }
        return ScoreAssessment(
            score: finalScore,
            completeness: completeness,
            confidence: confidence,
            signals: signals
        )
    }

    private static func scoreTarget(
        _ result: InternationalTargetResult
    ) -> (score: Double, observedWeight: Double) {
        guard !result.attempts.isEmpty else { return (0, 0) }
        if result.attempts.allSatisfy({ $0.errorKind == .cancelled }) {
            return (0, 0)
        }
        let anyDNS = result.attempts.contains(where: \.dnsSucceeded)
        let anyTCP = result.attempts.contains(where: \.tcpSucceeded)
        let anyTLS = result.attempts.contains(where: \.tlsSucceeded)
        let anyHTTP = result.attempts.contains(where: \.httpSucceeded)
        let anyServiceResponse = result.attempts.contains(where: \.serviceResponded)

        var score = 0.0
        var observed = 0.0

        observed += 15
        if anyDNS { score += 15 }

        observed += 20
        if anyTCP { score += 20 }

        observed += 20
        if anyTLS { score += 20 }

        observed += 20
        if anyHTTP {
            score += 20
        } else if anyServiceResponse {
            score += 8
        }

        if let average = result.averageTotalMilliseconds {
            observed += 15
            switch average {
            case ...800: score += 15
            case ...1_800: score += 12
            case ...3_500: score += 8
            case ...6_000: score += 4
            default: break
            }
        }

        if let jitter = result.jitterMilliseconds {
            observed += 10
            switch jitter {
            case ...80: score += 10
            case ...200: score += 8
            case ...500: score += 4
            default: break
            }
        }

        return (score, observed)
    }
}

public struct PublicIPProfile: Codable, Equatable, Sendable {
    public let ip: String
    public let ipVersion: String?
    public let country: String?
    public let countryCode: String?
    public let region: String?
    public let city: String?
    public let latitude: Double?
    public let longitude: Double?
    public let asn: String?
    public let asOrganization: String?
    public let isp: String?
    public let timezoneIdentifier: String?
    public let source: String

    public init(
        ip: String,
        ipVersion: String?,
        country: String?,
        countryCode: String?,
        region: String?,
        city: String?,
        latitude: Double?,
        longitude: Double?,
        asn: String?,
        asOrganization: String?,
        isp: String?,
        timezoneIdentifier: String?,
        source: String
    ) {
        self.ip = ip
        self.ipVersion = ipVersion
        self.country = country
        self.countryCode = countryCode
        self.region = region
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
        self.asn = asn
        self.asOrganization = asOrganization
        self.isp = isp
        self.timezoneIdentifier = timezoneIdentifier
        self.source = source
    }
}

public struct IPRiskProfile: Codable, Equatable, Sendable {
    public let ip: String?
    public let isVPN: Bool?
    public let isProxy: Bool?
    public let isTor: Bool?
    public let isAnonymous: Bool?
    public let isScraper: Bool?
    public let isRelay: Bool?
    public let isHosting: Bool?
    public let isResidentialProxy: Bool?
    public let isCompromised: Bool?
    public let isAnycast: Bool?
    public let riskScore: Int?
    public let providerConfidence: Int?
    public let attackCount: Int?
    public let networkType: String?
    public let provider: String?
    public let asn: String?
    public let organization: String?
    public let lastSeen: String?
    public let lastUpdated: String?
    public let source: String

    public init(
        ip: String?,
        isVPN: Bool?,
        isProxy: Bool?,
        isTor: Bool?,
        isAnonymous: Bool? = nil,
        isScraper: Bool? = nil,
        isRelay: Bool?,
        isHosting: Bool?,
        isResidentialProxy: Bool?,
        isCompromised: Bool?,
        isAnycast: Bool?,
        riskScore: Int?,
        providerConfidence: Int? = nil,
        attackCount: Int?,
        networkType: String?,
        provider: String?,
        asn: String?,
        organization: String?,
        lastSeen: String?,
        lastUpdated: String? = nil,
        source: String
    ) {
        self.ip = ip
        self.isVPN = isVPN
        self.isProxy = isProxy
        self.isTor = isTor
        self.isAnonymous = isAnonymous
        self.isScraper = isScraper
        self.isRelay = isRelay
        self.isHosting = isHosting
        self.isResidentialProxy = isResidentialProxy
        self.isCompromised = isCompromised
        self.isAnycast = isAnycast
        self.riskScore = riskScore
        self.providerConfidence = providerConfidence
        self.attackCount = attackCount
        self.networkType = networkType
        self.provider = provider
        self.asn = asn
        self.organization = organization
        self.lastSeen = lastSeen
        self.lastUpdated = lastUpdated
        self.source = source
    }
}

public struct PublicNetworkHistorySummary: Codable, Equatable, Sendable {
    public let countryCode: String?
    public let asn: String?
    public let networkType: String?
    public let sources: [String]

    public init(
        countryCode: String?,
        asn: String?,
        networkType: String?,
        sources: [String]
    ) {
        self.countryCode = countryCode
        self.asn = asn
        self.networkType = networkType
        self.sources = sources
    }
}

public enum IPWhoIsParser {
    public static func parse(data: Data) throws -> PublicIPProfile {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetworkDiagnosticsParsingError.invalidResponse
        }
        if let success = bool(root["success"]), !success {
            throw NetworkDiagnosticsParsingError.providerRejected(
                string(root["message"]) ?? "ipwho.is request failed"
            )
        }
        guard let ip = string(root["ip"]), !ip.isEmpty else {
            throw NetworkDiagnosticsParsingError.missingRequiredField("ip")
        }
        let connection = root["connection"] as? [String: Any]
        let timezone = root["timezone"] as? [String: Any]
        return PublicIPProfile(
            ip: ip,
            ipVersion: string(root["type"]),
            country: string(root["country"]),
            countryCode: string(root["country_code"]),
            region: string(root["region"]),
            city: string(root["city"]),
            latitude: double(root["latitude"]),
            longitude: double(root["longitude"]),
            asn: normalizedASN(connection?["asn"]),
            asOrganization: string(connection?["org"]),
            isp: string(connection?["isp"]),
            timezoneIdentifier: string(timezone?["id"]),
            source: "ipwho.is"
        )
    }
}

public enum ProxyCheckParser {
    public static func parse(data: Data, queriedIP: String? = nil) throws -> IPRiskProfile {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetworkDiagnosticsParsingError.invalidResponse
        }
        if let status = string(root["status"])?.lowercased(),
           status != "ok" && status != "success" && status != "warning" {
            throw NetworkDiagnosticsParsingError.providerRejected(
                string(root["message"]) ?? status
            )
        }

        let payload = locatePayload(root: root, queriedIP: queriedIP)
        guard let payload else {
            throw NetworkDiagnosticsParsingError.missingRequiredField("IP result")
        }
        let detections = firstDictionary(
            in: payload,
            keys: ["detections", "detection", "security"]
        )
        let network = firstDictionary(
            in: payload,
            keys: ["network", "connection", "asn"]
        )
        let risk = firstDictionary(in: payload, keys: ["risk", "risk_data"])
        let attacks = firstDictionary(
            in: payload,
            keys: ["attacks", "attack_history", "history"]
        )
        let hasAttackHistoryField = [
            "attacks",
            "attack_history",
            "history"
        ].contains { payload.keys.contains($0) }
        let operatorInfo = firstDictionary(in: payload, keys: ["operator"])
        let operatorServices = (operatorInfo?["services"] as? [Any])?
            .compactMap(string)

        let type = firstString(
            [network, payload],
            keys: ["type", "network_type", "connection_type"]
        )
        let provider = firstString(
            [network, payload],
            keys: ["provider", "isp"]
        )
        let organization = firstString(
            [network, payload],
            keys: ["organisation", "organization", "org"]
        )
        let asn = normalizedASN(
            firstValue([network, payload], keys: ["asn", "as_number"])
        )
        let riskScore = firstInteger(
            [risk, payload],
            keys: ["score", "risk_score", "risk"]
        )
        let attackCount = firstInteger(
            [attacks, payload],
            keys: ["count", "total", "reports", "attack_count"]
        ) ?? attacks.map(summedIntegerValues)
            ?? (hasAttackHistoryField ? 0 : nil)
        let anonymous = firstBoolean(
            [detections, payload],
            keys: ["anonymous", "is_anonymous"]
        )
        let explicitResidentialProxy = firstBoolean(
            [detections, payload],
            keys: ["residential_proxy", "is_residential_proxy"]
        )
        let operatorResidentialProxy = operatorServices.map { services in
            services.contains {
                $0.localizedCaseInsensitiveContains("residential_prox")
            }
        }
        let residentialProxy: Bool?
        if let explicitResidentialProxy {
            residentialProxy = explicitResidentialProxy
        } else if let operatorResidentialProxy {
            residentialProxy = operatorResidentialProxy
        } else if anonymous == false {
            residentialProxy = false
        } else {
            residentialProxy = nil
        }

        return IPRiskProfile(
            ip: string(payload["ip"]) ?? queriedIP,
            isVPN: firstBoolean([detections, payload], keys: ["vpn", "is_vpn"]),
            isProxy: firstBoolean([detections, payload], keys: ["proxy", "is_proxy"]),
            isTor: firstBoolean([detections, payload], keys: ["tor", "is_tor"]),
            isAnonymous: firstBoolean(
                [detections, payload],
                keys: ["anonymous", "is_anonymous"]
            ),
            isScraper: firstBoolean(
                [detections, payload],
                keys: ["scraper", "is_scraper"]
            ),
            isRelay: firstBoolean([detections, payload], keys: ["relay", "is_relay"]),
            isHosting: firstBoolean(
                [detections, payload],
                keys: ["hosting", "host", "is_hosting"]
            ) ?? type.map { $0.localizedCaseInsensitiveContains("hosting") },
            isResidentialProxy: residentialProxy,
            isCompromised: firstBoolean(
                [detections, payload],
                keys: ["compromised", "is_compromised"]
            ),
            isAnycast: firstBoolean([network, payload], keys: ["anycast", "is_anycast"]),
            riskScore: riskScore,
            providerConfidence: firstInteger(
                [detections, payload],
                keys: ["confidence", "confidence_score"]
            ),
            attackCount: attackCount,
            networkType: type,
            provider: provider,
            asn: asn,
            organization: organization,
            lastSeen: firstString(
                [detections, risk, attacks, payload],
                keys: ["last_seen", "last_reported", "updated_at"]
            ),
            lastUpdated: firstString(
                [payload],
                keys: ["last_updated", "updated_at"]
            ),
            source: "proxycheck.io"
        )
    }

    private static func locatePayload(
        root: [String: Any],
        queriedIP: String?
    ) -> [String: Any]? {
        if root["ip"] != nil,
           root["detections"] != nil || root["network"] != nil {
            return root
        }
        if let queriedIP,
           let direct = root[queriedIP] as? [String: Any] {
            return direct
        }
        if let data = root["data"] as? [[String: Any]], let first = data.first {
            return first
        }
        if let result = root["result"] as? [String: Any] {
            return result
        }
        for (key, value) in root {
            guard key != "status",
                  key != "message",
                  let dictionary = value as? [String: Any] else {
                continue
            }
            if key.contains(".") || key.contains(":") || dictionary["ip"] != nil {
                return dictionary
            }
        }
        return nil
    }
}

public enum NetworkDiagnosticsParsingError: LocalizedError, Equatable {
    case invalidResponse
    case missingRequiredField(String)
    case providerRejected(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "服务返回了无法解析的数据。"
        case let .missingRequiredField(field):
            "服务结果缺少必要字段：\(field)"
        case let .providerRejected(message):
            "服务暂时无法完成查询：\(message)"
        }
    }
}

public enum IPReputationAssessmentEngine {
    public static func assess(_ profile: IPRiskProfile?) -> ScoreAssessment {
        guard let profile else {
            return ScoreAssessment(
                score: nil,
                completeness: 0,
                confidence: 0,
                signals: [
                    AssessmentSignal(
                        id: "reputation.missing",
                        titleKey: "IP 信誉数据不足",
                        detailKey: "第三方信誉服务未返回可用结果，未据此推算分数。",
                        impact: .unavailable
                    )
                ]
            )
        }

        let hasPositiveDetection = [
            profile.isVPN,
            profile.isProxy,
            profile.isTor,
            profile.isRelay,
            profile.isHosting,
            profile.isResidentialProxy,
            profile.isCompromised
        ].contains { $0 == true }
        var observed: [Bool] = [
            profile.isVPN != nil,
            profile.isProxy != nil,
            profile.isTor != nil,
            profile.isRelay != nil,
            profile.isHosting != nil,
            profile.isResidentialProxy != nil,
            profile.isCompromised != nil,
            profile.riskScore != nil,
            profile.attackCount != nil,
            profile.lastUpdated != nil
        ]
        if hasPositiveDetection {
            observed.append(profile.providerConfidence != nil)
            observed.append(profile.lastSeen != nil)
        }
        let completeness = Double(observed.filter { $0 }.count) / Double(observed.count)
        var score = 100
        var signals: [AssessmentSignal] = []

        if profile.isCompromised == true {
            score -= 35
            signals.append(.init(
                id: "reputation.compromised",
                titleKey: "发现受损或滥用风险信号",
                detailKey: "单一数据源将该出口标记为可能受损，需要结合其他证据复核。",
                impact: .risk,
                scoreDelta: -35
            ))
        }
        if let attackCount = profile.attackCount, attackCount > 0 {
            let deduction = min(25, 5 + Int(log10(Double(attackCount) + 1) * 8))
            score -= deduction
            signals.append(.init(
                id: "reputation.attacks",
                titleKey: "存在历史滥用报告",
                detailKey: "报告数量和时间新鲜度会影响可信度，不能单独证明当前连接恶意。",
                impact: .risk,
                scoreDelta: -deduction
            ))
        }
        if let risk = profile.riskScore {
            let deduction: Int
            switch risk {
            case 90...: deduction = 25
            case 70..<90: deduction = 15
            case 40..<70: deduction = 7
            default: deduction = 0
            }
            if deduction > 0 {
                score -= deduction
                signals.append(.init(
                    id: "reputation.provider-risk",
                    titleKey: "数据源风险值偏高",
                    detailKey: "这是供应商模型信号，不是确定的恶意判定。",
                    impact: risk >= 70 ? .risk : .caution,
                    scoreDelta: -deduction
                ))
            }
        }
        if profile.isProxy == true {
            score -= 5
            signals.append(.init(
                id: "reputation.proxy",
                titleKey: "检测到公共代理属性",
                detailKey: "代理属性与恶意风险分开显示；它可能影响部分服务访问。",
                impact: .caution,
                scoreDelta: -5
            ))
        }
        if profile.isResidentialProxy == true {
            score -= 4
            signals.append(.init(
                id: "reputation.residential-proxy",
                titleKey: "检测到住宅代理属性",
                detailKey: "住宅代理标签可能存在误判，不代表当前用户行为异常。",
                impact: .caution,
                scoreDelta: -4
            ))
        }
        if profile.isTor == true {
            score -= 3
            signals.append(.init(
                id: "reputation.tor",
                titleKey: "检测到 Tor 出口属性",
                detailKey: "Tor 本身不等于恶意，但经常受到网站额外限制。",
                impact: .informational,
                scoreDelta: -3
            ))
        }
        if profile.isVPN == true {
            signals.append(.init(
                id: "reputation.vpn",
                titleKey: "检测到 VPN 属性",
                detailKey: "VPN 属性不会自动降低 IP 信誉分。",
                impact: .informational
            ))
        }
        if profile.isHosting == true {
            signals.append(.init(
                id: "reputation.hosting",
                titleKey: "数据中心或 Hosting 网络",
                detailKey: "数据中心属性不是恶意结论，但可能触发部分平台风控。",
                impact: .informational
            ))
        }
        if hasPositiveDetection {
            if let providerConfidence = profile.providerConfidence {
                signals.append(.init(
                    id: "reputation.provider-confidence",
                    titleKey: providerConfidence >= 70
                        ? "供应商检测置信度较高"
                        : "供应商检测置信度有限",
                    detailKey: providerConfidence >= 70
                        ? "该数值仅表示供应商对自身标签的把握，不代表网络绝对安全或恶意。"
                        : "低置信度标签更容易误判，已降低本轮评估置信度。",
                    impact: providerConfidence >= 70 ? .informational : .caution
                ))
            } else {
                signals.append(.init(
                    id: "reputation.provider-confidence-missing",
                    titleKey: "供应商置信度缺失",
                    detailKey: "存在风险标签但没有对应置信度，已按数据不完整处理。",
                    impact: .unavailable
                ))
            }
        }

        signals.append(.init(
            id: "reputation.single-provider",
            titleKey: "当前为单一信誉数据源",
            detailKey: "供应商判断只作为风险信号，不能包装成确定事实。",
            impact: .unavailable
        ))

        guard completeness >= 0.35 else {
            return ScoreAssessment(
                score: nil,
                completeness: completeness,
                confidence: min(0.35, completeness),
                signals: signals
            )
        }
        score = min(94, max(0, score))
        var confidence = min(0.65, completeness * 0.7)
        if hasPositiveDetection {
            if let providerConfidence = profile.providerConfidence {
                confidence = min(
                    confidence,
                    0.25 + (Double(providerConfidence) / 100) * 0.4
                )
            } else {
                confidence = min(confidence, 0.4)
            }
        }
        return ScoreAssessment(
            score: score,
            completeness: completeness,
            confidence: confidence,
            signals: signals
        )
    }
}

public struct PrivacyConsistencyInput: Codable, Equatable, Sendable {
    public let ipv4CountryCode: String?
    public let ipv6CountryCode: String?
    public let ipv4ASN: String?
    public let ipv6ASN: String?
    public let publicEndpointAgreement: Bool?
    public let timeZoneMatchesExit: Bool?
    public let localeMatchesExit: Bool?
    public let proxyEnabled: Bool
    public let tunnelInterfaceCount: Int
    public let primaryInterfaceIsTunnel: Bool
    public let possibleIPv6Bypass: Bool?
    public let dnsLeakVerified: Bool?
    public let webRTCLeakVerified: Bool?

    public init(
        ipv4CountryCode: String?,
        ipv6CountryCode: String?,
        ipv4ASN: String?,
        ipv6ASN: String?,
        publicEndpointAgreement: Bool?,
        timeZoneMatchesExit: Bool?,
        localeMatchesExit: Bool?,
        proxyEnabled: Bool,
        tunnelInterfaceCount: Int,
        primaryInterfaceIsTunnel: Bool,
        possibleIPv6Bypass: Bool?,
        dnsLeakVerified: Bool? = nil,
        webRTCLeakVerified: Bool? = nil
    ) {
        self.ipv4CountryCode = ipv4CountryCode
        self.ipv6CountryCode = ipv6CountryCode
        self.ipv4ASN = ipv4ASN
        self.ipv6ASN = ipv6ASN
        self.publicEndpointAgreement = publicEndpointAgreement
        self.timeZoneMatchesExit = timeZoneMatchesExit
        self.localeMatchesExit = localeMatchesExit
        self.proxyEnabled = proxyEnabled
        self.tunnelInterfaceCount = max(0, tunnelInterfaceCount)
        self.primaryInterfaceIsTunnel = primaryInterfaceIsTunnel
        self.possibleIPv6Bypass = possibleIPv6Bypass
        self.dnsLeakVerified = dnsLeakVerified
        self.webRTCLeakVerified = webRTCLeakVerified
    }
}

public enum PrivacyConsistencyAssessmentEngine {
    public static func assess(_ input: PrivacyConsistencyInput?) -> ScoreAssessment {
        guard let input else {
            return ScoreAssessment(
                score: nil,
                completeness: 0,
                confidence: 0,
                signals: [
                    AssessmentSignal(
                        id: "privacy.missing",
                        titleKey: "隐私一致性数据不足",
                        detailKey: "未查询公网出口或本机网络路径，无法形成评分。",
                        impact: .unavailable
                    )
                ]
            )
        }

        var score = 100
        var signals: [AssessmentSignal] = []
        var observed = 2
        let maximumObserved = 9

        if let v4Country = input.ipv4CountryCode,
           let v6Country = input.ipv6CountryCode {
            observed += 1
            if v4Country.caseInsensitiveCompare(v6Country) != .orderedSame {
                score -= 25
                signals.append(.init(
                    id: "privacy.ip-country-split",
                    titleKey: "IPv4 与 IPv6 出口地区不一致",
                    detailKey: "可能存在分流或 IPv6 未经过预期代理路径，需要复核。",
                    impact: .risk,
                    scoreDelta: -25
                ))
            } else {
                signals.append(.init(
                    id: "privacy.ip-country-match",
                    titleKey: "IPv4 与 IPv6 出口地区一致",
                    detailKey: "当前可见的双栈出口地区没有明显冲突。",
                    impact: .positive
                ))
            }
        } else {
            signals.append(.init(
                id: "privacy.single-stack",
                titleKey: "仅获得单栈出口数据",
                detailKey: "缺少 IPv4 或 IPv6 结果，不能验证双栈是否一致。",
                impact: .unavailable
            ))
        }

        if let v4ASN = input.ipv4ASN, let v6ASN = input.ipv6ASN {
            observed += 1
            if v4ASN.caseInsensitiveCompare(v6ASN) != .orderedSame {
                score -= 12
                signals.append(.init(
                    id: "privacy.asn-split",
                    titleKey: "IPv4 与 IPv6 ASN 不一致",
                    detailKey: "双栈可能经过不同运营商或隧道路径。",
                    impact: .caution,
                    scoreDelta: -12
                ))
            }
        }

        if let agreement = input.publicEndpointAgreement {
            observed += 1
            if !agreement {
                score -= 22
                signals.append(.init(
                    id: "privacy.endpoint-mismatch",
                    titleKey: "公网 IP 查询结果不一致",
                    detailKey: "不同查询端点看到的出口不一致，可能存在分流或短时网络切换。",
                    impact: .risk,
                    scoreDelta: -22
                ))
            }
        }

        if let matches = input.timeZoneMatchesExit {
            observed += 1
            if !matches {
                score -= 7
                signals.append(.init(
                    id: "privacy.timezone",
                    titleKey: "系统时区与出口地区存在差异",
                    detailKey: "这只是环境一致性信号，旅行或手动时区设置也会导致差异。",
                    impact: .caution,
                    scoreDelta: -7
                ))
            }
        }

        if let matches = input.localeMatchesExit {
            observed += 1
            if !matches {
                score -= 3
                signals.append(.init(
                    id: "privacy.locale",
                    titleKey: "系统地区与出口地区存在差异",
                    detailKey: "语言和地区偏好并不等于真实位置，因此只做轻量提示。",
                    impact: .informational,
                    scoreDelta: -3
                ))
            }
        }

        if let bypass = input.possibleIPv6Bypass {
            observed += 1
            if bypass {
                score -= 30
                signals.append(.init(
                    id: "privacy.ipv6-bypass",
                    titleKey: "存在 IPv6 绕过代理的迹象",
                    detailKey: "该结论来自可复现的双栈出口差异，仍建议用目标 VPN 的官方测试复核。",
                    impact: .risk,
                    scoreDelta: -30
                ))
            }
        }

        if input.proxyEnabled || input.tunnelInterfaceCount > 0 {
            signals.append(.init(
                id: "privacy.route-tools",
                titleKey: "检测到代理或隧道路径",
                detailKey: "代理或隧道是网络路径属性，本身不会被判定为风险。",
                impact: .informational
            ))
        }
        if input.primaryInterfaceIsTunnel {
            signals.append(.init(
                id: "privacy.primary-tunnel",
                titleKey: "当前主要路径使用隧道接口",
                detailKey: "主流量可能正在通过 VPN 或系统隧道。",
                impact: .informational
            ))
        }

        if let leak = input.dnsLeakVerified {
            observed += 1
            if leak {
                score -= 30
                signals.append(.init(
                    id: "privacy.dns-leak",
                    titleKey: "已获得 DNS 出口不一致证据",
                    detailKey: "该项仅在唯一域名与权威 DNS 服务可复现时成立。",
                    impact: .risk,
                    scoreDelta: -30
                ))
            }
        } else {
            signals.append(.init(
                id: "privacy.dns-unverified",
                titleKey: "DNS 泄漏未验证",
                detailKey: "仅查看本机 DNS 地址不能证明泄漏；需要唯一域名和权威 DNS 服务配合。",
                impact: .unavailable
            ))
        }

        if let leak = input.webRTCLeakVerified {
            observed += 1
            if leak {
                score -= 25
            }
        } else {
            signals.append(.init(
                id: "privacy.webrtc-unverified",
                titleKey: "浏览器 WebRTC 未验证",
                detailKey: "原生 App 无法证明所有浏览器不存在 WebRTC 泄漏。",
                impact: .unavailable
            ))
        }

        let completeness = min(1, Double(observed) / Double(maximumObserved))
        guard completeness >= 0.4 else {
            return ScoreAssessment(
                score: nil,
                completeness: completeness,
                confidence: min(0.4, completeness),
                signals: signals
            )
        }
        score = min(96, max(0, score))
        return ScoreAssessment(
            score: score,
            completeness: completeness,
            confidence: min(0.72, completeness * 0.78),
            signals: signals
        )
    }
}

public enum CombinedNetworkAssessmentEngine {
    public static func assess(
        international: ScoreAssessment?,
        reputation: ScoreAssessment?,
        privacy: ScoreAssessment?
    ) -> ScoreAssessment {
        let components: [(String, ScoreAssessment?, Double)] = [
            ("国际连通评分", international, 0.4),
            ("IP 信誉评分", reputation, 0.3),
            ("隐私一致性评分", privacy, 0.3)
        ]
        var available: [
            (
                name: String,
                assessment: ScoreAssessment,
                score: Int,
                weight: Double
            )
        ] = []
        for (name, assessment, weight) in components {
            guard let assessment, let score = assessment.score else { continue }
            available.append((name, assessment, score, weight))
        }
        guard available.count >= 2 else {
            return ScoreAssessment(
                score: nil,
                completeness: Double(available.count) / Double(components.count),
                confidence: 0,
                signals: [
                    AssessmentSignal(
                        id: "combined.insufficient",
                        titleKey: "综合结论数据不足",
                        detailKey: "至少需要两类可用评分，缺失数据不会按满分处理。",
                        impact: .unavailable
                    )
                ]
            )
        }

        let weightSum = available.reduce(0.0) { $0 + $1.weight }
        let weightedScore = available.reduce(0.0) {
            $0 + Double($1.score) * $1.weight
        } / weightSum
        let completeness = available.reduce(0.0) {
            $0 + $1.assessment.completeness * $1.weight
        } / weightSum
        let confidence = available.reduce(0.0) {
            $0 + $1.assessment.confidence * $1.weight
        } / weightSum
        let missingPenalty = 0.9 + 0.1 * completeness
        var finalScore = Int((weightedScore * missingPenalty).rounded())
        if available.count < components.count || completeness < 0.999 {
            finalScore = min(finalScore, 96)
        }

        let componentSignals = available.map { item in
            AssessmentSignal(
                id: "combined.\(item.name)",
                titleKey: item.name,
                detailKey: "\(item.score) / 100",
                impact: item.assessment.grade == .risk || item.assessment.grade == .poor
                    ? .caution
                    : .positive
            )
        }
        return ScoreAssessment(
            score: finalScore,
            completeness: completeness,
            confidence: confidence,
            signals: componentSignals
        )
    }
}

public struct NetworkDiagnosticsRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let completedAt: Date
    public let targets: [InternationalTargetResult]
    public let internationalAssessment: ScoreAssessment
    public let publicSummary: PublicNetworkHistorySummary?
    public let reputationAssessment: ScoreAssessment?
    public let privacyAssessment: ScoreAssessment?
    public let combinedAssessment: ScoreAssessment

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        completedAt: Date,
        targets: [InternationalTargetResult],
        internationalAssessment: ScoreAssessment,
        publicSummary: PublicNetworkHistorySummary?,
        reputationAssessment: ScoreAssessment?,
        privacyAssessment: ScoreAssessment?,
        combinedAssessment: ScoreAssessment
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.targets = targets
        self.internationalAssessment = internationalAssessment
        self.publicSummary = publicSummary
        self.reputationAssessment = reputationAssessment
        self.privacyAssessment = privacyAssessment
        self.combinedAssessment = combinedAssessment
    }
}

public struct NetworkDiagnosticsHistoryArchive: Codable, Sendable {
    public static let currentSchemaVersion = 1
    public let schemaVersion: Int
    public let savedAt: Date
    public let records: [NetworkDiagnosticsRecord]

    public init(
        schemaVersion: Int = NetworkDiagnosticsHistoryArchive.currentSchemaVersion,
        savedAt: Date = Date(),
        records: [NetworkDiagnosticsRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.savedAt = savedAt
        self.records = records
    }
}

public final class NetworkDiagnosticsHistoryStore: @unchecked Sendable {
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
        self.historyURL = self.appSupportURL
            .appendingPathComponent("network-diagnostics-history.json")
        self.backupURL = self.appSupportURL
            .appendingPathComponent("network-diagnostics-history.previous.json")
        self.corruptDirectoryURL = self.appSupportURL.appendingPathComponent(
            "Recovered Network History",
            isDirectory: true
        )
        self.maximumRecords = max(1, maximumRecords)
    }

    public func load() throws -> [NetworkDiagnosticsRecord] {
        try withLock {
            try fileManager.createDirectory(
                at: appSupportURL,
                withIntermediateDirectories: true
            )
            return try loadRecordsRecoveringIfNeeded()
        }
    }

    @discardableResult
    public func append(_ record: NetworkDiagnosticsRecord) throws -> [NetworkDiagnosticsRecord] {
        try withLock {
            try fileManager.createDirectory(
                at: appSupportURL,
                withIntermediateDirectories: true
            )
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

    private func loadRecordsRecoveringIfNeeded() throws -> [NetworkDiagnosticsRecord] {
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

    private func writeRecords(_ records: [NetworkDiagnosticsRecord]) throws {
        let data = try encoder.encode(
            NetworkDiagnosticsHistoryArchive(records: records)
        )
        _ = try decodeRecords(data)
        if fileManager.fileExists(atPath: historyURL.path),
           let currentData = try? Data(contentsOf: historyURL),
           (try? decodeRecords(currentData)) != nil {
            try currentData.write(to: backupURL, options: [.atomic])
        }
        try data.write(to: historyURL, options: [.atomic])
    }

    private func decodeRecords(_ data: Data) throws -> [NetworkDiagnosticsRecord] {
        try decoder.decode(NetworkDiagnosticsHistoryArchive.self, from: data)
            .records
            .sorted { $0.completedAt > $1.completedAt }
    }

    private func preserveCorruptPrimary() throws {
        try fileManager.createDirectory(
            at: corruptDirectoryURL,
            withIntermediateDirectories: true
        )
        let destination = corruptDirectoryURL.appendingPathComponent(
            "network-diagnostics-history-corrupt-\(UUID().uuidString).json"
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

private func string(_ value: Any?) -> String? {
    if let value = value as? String {
        return value
    }
    if let value = value as? NSNumber {
        return value.stringValue
    }
    return nil
}

private func bool(_ value: Any?) -> Bool? {
    if let value = value as? Bool {
        return value
    }
    if let value = value as? NSNumber {
        return value.boolValue
    }
    if let value = value as? String {
        switch value.lowercased() {
        case "true", "yes", "1": return true
        case "false", "no", "0": return false
        default: return nil
        }
    }
    return nil
}

private func double(_ value: Any?) -> Double? {
    if let value = value as? NSNumber {
        return value.doubleValue
    }
    if let value = value as? String {
        return Double(value)
    }
    return nil
}

private func normalizedASN(_ value: Any?) -> String? {
    guard let value = string(value)?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty else {
        return nil
    }
    return value.uppercased().hasPrefix("AS") ? value.uppercased() : "AS\(value)"
}

private func firstDictionary(
    in root: [String: Any],
    keys: [String]
) -> [String: Any]? {
    for key in keys {
        if let value = root[key] as? [String: Any] {
            return value
        }
    }
    return nil
}

private func firstValue(
    _ dictionaries: [[String: Any]?],
    keys: [String]
) -> Any? {
    for dictionary in dictionaries.compactMap({ $0 }) {
        for key in keys where dictionary[key] != nil {
            return dictionary[key]
        }
    }
    return nil
}

private func firstString(
    _ dictionaries: [[String: Any]?],
    keys: [String]
) -> String? {
    string(firstValue(dictionaries, keys: keys))
}

private func firstInteger(
    _ dictionaries: [[String: Any]?],
    keys: [String]
) -> Int? {
    double(firstValue(dictionaries, keys: keys)).map { Int($0.rounded()) }
}

private func firstBoolean(
    _ dictionaries: [[String: Any]?],
    keys: [String]
) -> Bool? {
    bool(firstValue(dictionaries, keys: keys))
}

private func summedIntegerValues(_ dictionary: [String: Any]) -> Int {
    dictionary.values.reduce(into: 0) { total, value in
        if let number = double(value), number >= 0 {
            total += Int(number.rounded())
        }
    }
}
