import AppKit
import ShixinNetworkDiagnosticsCore
import ShixinStressPowerCore
import SwiftUI

struct InternationalDiagnosticsView: View {
    @ObservedObject var controller: InternationalDiagnosticsController
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            InternationalDiagnosticsHero(
                controller: controller,
                reduceMotion: reduceMotion
            )

            if let error = controller.errorMessage {
                DiagnosticsNoticeCard(
                    message: error,
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .orange
                )
            }
            if let warning = controller.historyWarning {
                DiagnosticsNoticeCard(
                    message: warning,
                    systemImage: "externaldrive.badge.exclamationmark",
                    tint: .orange
                )
            }

            InternationalTargetsCard(
                results: controller.displayTargetResults,
                isRunning: controller.phase.isRunning
            )

            if let record = controller.displayRecord {
                DiagnosticsAssessmentSection(record: record)
            }

            InternationalDiagnosticsHistoryCard(
                records: controller.history,
                historyURL: controller.historyURL
            )
        }
    }
}

private struct InternationalDiagnosticsHero: View {
    @ObservedObject var controller: InternationalDiagnosticsController
    let reduceMotion: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            scoreRing
                .fixedSize()
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
        }
        .labGlassCard(padding: 20, cornerRadius: 20)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 7) {
                Text(L10n.t("国际网络诊断"))
                    .font(.title2.weight(.semibold))
                InfoHelpButton(
                    title: "国际网络诊断",
                    message: "对 Google、YouTube、X、Instagram 与 GitHub 进行小体积、可取消的 DNS、TCP、TLS 与 HTTP 可达性诊断。平台主页响应只用于判断连接质量，绝不会伪装成平台带宽测速；单一目标失败也不等于整个国际网络不可用。"
                )
                Spacer(minLength: 18)
                StatusPill(
                    text: controller.phase.titleKey,
                    systemImage: controller.phase.systemImage,
                    tint: controller.phase.tint
                )
            }

            Text(L10n.t("逐阶段检查国际线路、代理与 VPN 访问质量，结果有依据、有完整度。"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if controller.phase.isRunning {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: controller.progress)
                        .progressViewStyle(.linear)
                        .tint(.cyan)
                    HStack {
                        Text(L10n.t(controller.phase.titleKey))
                        Spacer()
                        Text(
                            "\(Int((controller.progress * 100).rounded()))% · \(elapsedText)"
                        )
                        .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } else if let record = controller.displayRecord {
                HStack(spacing: 14) {
                    Label(
                        record.completedAt.formatted(
                            date: .abbreviated,
                            time: .shortened
                        ),
                        systemImage: "clock"
                    )
                    Label(
                        String(
                            format: L10n.t("%d / %d 个目标可访问"),
                            record.targets.filter {
                                $0.successfulAttempts.count > 0
                            }.count,
                            record.targets.count
                        ),
                        systemImage: "checkmark.circle"
                    )
                    if let country = record.publicSummary?.countryCode {
                        Label(country, systemImage: "globe.asia.australia")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text(L10n.t("每个目标进行 3 次小流量请求，通常在 10–30 秒内完成。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle(
                isOn: $controller.includesIPAnalysis
            ) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("同时分析公网出口与 IP 信誉"))
                        .font(.callout.weight(.medium))
                    Text(L10n.t("关闭时只进行五个目标的连通性诊断。"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .toggleStyle(.switch)
            .disabled(controller.phase.isRunning)

            if controller.includesIPAnalysis {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(.orange)
                Text(L10n.t("查询公网出口及 IP 信誉时，网络信息查询服务会接收到当前公网 IP；不会上传本机硬件数据、历史文件或个人内容。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                }
            }

            HStack(spacing: 12) {
                if controller.phase.isRunning {
                    Button {
                        controller.cancel()
                    } label: {
                        Label("取消诊断", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button {
                        controller.start()
                    } label: {
                        Label(
                            controller.currentRecord == nil ? "开始国际诊断" : "重新诊断",
                            systemImage: "point.3.connected.trianglepath.dotted"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.10, green: 0.52, blue: 0.94))
                }

                Text(L10n.t("仅在你主动开始后联网，可随时取消，不在后台轮询。"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var scoreRing: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 11)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    AngularGradient(
                        colors: [.cyan, .blue, .indigo, .cyan],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 11, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(
                    reduceMotion ? nil : .snappy(duration: 0.32, extraBounce: 0),
                    value: ringProgress
                )
            VStack(spacing: 6) {
                Image(systemName: controller.phase.systemImage)
                    .font(.system(size: 27, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(controller.phase.tint)
                if controller.phase.isRunning {
                    Text("\(Int((controller.progress * 100).rounded()))%")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                } else if let score = controller.displayRecord?
                    .internationalAssessment.score {
                    Text("\(score)")
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                    Text(L10n.t("国际连通"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .font(.title2.weight(.semibold))
                    Text(L10n.t("等待诊断"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 156, height: 156)
        .accessibilityHidden(true)
    }

    private var ringProgress: Double {
        if controller.phase.isRunning {
            return max(0.025, controller.progress)
        }
        guard let score = controller.displayRecord?.internationalAssessment.score else {
            return 0.025
        }
        return max(0.025, Double(score) / 100)
    }

    private var elapsedText: String {
        let seconds = Int(controller.elapsedSeconds.rounded(.down))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct InternationalTargetsCard: View {
    let results: [InternationalTargetResult]
    let isRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: "目标诊断",
                systemImage: "globe.desk",
                help: "每个目标最多进行 3 次小体积 HTTPS 请求。DNS、TCP、TLS、首包与总耗时来自实际解析和 URLSessionTaskMetrics；HTTP 403、429 或 5xx 会标记为目标服务响应异常，而不是直接判断 VPN 失效。"
            )

            VStack(spacing: 8) {
                ForEach(InternationalTargetID.allCases) { target in
                    InternationalTargetRow(
                        target: target,
                        result: results.first(where: { $0.id == target }),
                        isRunning: isRunning
                    )
                }
            }
        }
        .labGlassCard()
    }
}

private struct InternationalTargetRow: View {
    let target: InternationalTargetID
    let result: InternationalTargetResult?
    let isRunning: Bool
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if let result {
                targetDetails(result)
                    .padding(.top, 11)
            } else {
                Text(L10n.t(isRunning ? "等待该目标返回数据。" : "开始诊断后显示连接阶段与耗时。"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 10)
            }
        } label: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    targetIdentity
                        .frame(width: 185, alignment: .leading)
                    stageSummary
                    Spacer(minLength: 8)
                    timingSummary
                        .frame(width: 220, alignment: .trailing)
                    statusPill
                }
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        targetIdentity
                        Spacer()
                        statusPill
                    }
                    HStack {
                        stageSummary
                        Spacer()
                        timingSummary
                    }
                }
            }
        }
        .tint(.secondary)
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(
            Color.white.opacity(0.028),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    private var targetIdentity: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(targetTint.opacity(0.14))
                Image(systemName: targetSymbol)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(targetTint)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(target.displayName)
                    .font(.callout.weight(.semibold))
                Text(result?.requestedHost ?? target.host)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    private var stageSummary: some View {
        HStack(spacing: 5) {
            stageChip("DNS", state: stageState(\.dnsSucceeded))
            stageChip("TCP", state: stageState(\.tcpSucceeded))
            stageChip("TLS", state: stageState(\.tlsSucceeded))
            stageChip("HTTP", state: httpStageState)
        }
    }

    private var timingSummary: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(averageText)
                .font(.callout.weight(.semibold).monospacedDigit())
            Text(jitterText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var statusPill: some View {
        let status = result.map(InternationalAssessmentEngine.targetStatus)
        return Text(L10n.t(status?.titleKey ?? (isRunning ? "检测中" : "未检测")))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(statusTint(status))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                statusTint(status).opacity(0.12),
                in: Capsule(style: .continuous)
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(statusTint(status).opacity(0.2), lineWidth: 1)
            }
            .fixedSize()
    }

    private func targetDetails(_ result: InternationalTargetResult) -> some View {
        let columns = [
            GridItem(.adaptive(minimum: 145, maximum: 250), spacing: 10)
        ]
        return VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                MiniDiagnosticValue(
                    title: "DNS 平均",
                    value: milliseconds(result.averageDNSMilliseconds),
                    symbol: "network"
                )
                MiniDiagnosticValue(
                    title: "建连平均",
                    value: milliseconds(result.averageConnectMilliseconds),
                    symbol: "link"
                )
                MiniDiagnosticValue(
                    title: "TLS 平均",
                    value: milliseconds(result.averageTLSMilliseconds),
                    symbol: "lock.shield"
                )
                MiniDiagnosticValue(
                    title: "首包 TTFB",
                    value: milliseconds(result.averageTTFBMilliseconds),
                    symbol: "bolt.horizontal"
                )
                MiniDiagnosticValue(
                    title: "完整响应",
                    value: milliseconds(result.averageTotalMilliseconds),
                    symbol: "stopwatch"
                )
                MiniDiagnosticValue(
                    title: "延迟波动",
                    value: milliseconds(result.jitterMilliseconds),
                    symbol: "waveform.path"
                )
                MiniDiagnosticValue(
                    title: "IPv4 / IPv6",
                    value: "\(reachable(result.resolvedIPv4)) / \(reachable(result.resolvedIPv6))",
                    symbol: "point.3.connected.trianglepath.dotted"
                )
                MiniDiagnosticValue(
                    title: "最终域名",
                    value: result.finalHost ?? "—",
                    symbol: "arrow.triangle.turn.up.right.diamond"
                )
                MiniDiagnosticValue(
                    title: "重定向",
                    value: String(
                        format: L10n.t("%d 次"),
                        result.redirectCount
                    ),
                    symbol: "arrow.triangle.branch"
                )
                MiniDiagnosticValue(
                    title: "有效请求",
                    value: "\(result.successfulAttempts.count) / \(result.requestedAttemptCount)",
                    symbol: "checkmark.circle"
                )
            }

            if let error = result.attempts.compactMap(\.errorKind).last {
                Label(errorTitle(error), systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func stageState(
        _ keyPath: KeyPath<InternationalProbeAttempt, Bool>
    ) -> DiagnosticStageState {
        guard let result else { return isRunning ? .waiting : .unknown }
        return result.attempts.contains(where: { $0[keyPath: keyPath] })
            ? .passed
            : .failed
    }

    private var httpStageState: DiagnosticStageState {
        guard let result else { return isRunning ? .waiting : .unknown }
        if result.attempts.contains(where: \.httpSucceeded) { return .passed }
        if result.attempts.contains(where: \.serviceResponded) { return .caution }
        return .failed
    }

    private func stageChip(
        _ title: String,
        state: DiagnosticStageState
    ) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(state.tint)
                .frame(width: 5, height: 5)
            Text(title)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(state.tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(state.tint.opacity(0.08), in: Capsule())
    }

    private var averageText: String {
        guard let result else {
            return L10n.t(isRunning ? "等待返回" : "—")
        }
        return String(
            format: L10n.t("平均 %.0f ms"),
            result.averageTotalMilliseconds ?? 0
        )
    }

    private var jitterText: String {
        guard let jitter = result?.jitterMilliseconds else {
            return L10n.t("波动 —")
        }
        return String(format: L10n.t("波动 %.0f ms"), jitter)
    }

    private func milliseconds(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f ms", value)
    }

    private func reachable(_ value: Bool) -> String {
        L10n.t(value ? "可达" : "未确认")
    }

    private func errorTitle(_ error: InternationalProbeErrorKind) -> String {
        let key: String
        switch error {
        case .dnsFailure: key = "DNS 解析失败"
        case .timeout: key = "连接超时"
        case .offline: key = "网络离线"
        case .connectionReset: key = "连接被重置"
        case .connectionFailure: key = "TCP 连接失败"
        case .tlsFailure: key = "TLS 握手失败"
        case .httpAbnormal: key = "目标服务响应异常"
        case .cancelled: key = "用户已取消"
        case .responseTooLarge: key = "响应超过诊断上限"
        case .unknown: key = "未知连接错误"
        }
        return L10n.t(key)
    }

    private func statusTint(_ status: InternationalTargetStatus?) -> Color {
        switch status {
        case .good: .green
        case .slow: .yellow
        case .partial: .orange
        case .unavailable: .red
        case .insufficient, .none: .secondary
        }
    }

    private var targetTint: Color {
        switch target {
        case .google: .blue
        case .youtube: .red
        case .x: .primary
        case .instagram: .purple
        case .github: .mint
        }
    }

    private var targetSymbol: String {
        switch target {
        case .google: "g.circle.fill"
        case .youtube: "play.rectangle.fill"
        case .x: "xmark"
        case .instagram: "camera.fill"
        case .github: "chevron.left.forwardslash.chevron.right"
        }
    }
}

private enum DiagnosticStageState {
    case waiting
    case passed
    case caution
    case failed
    case unknown

    var tint: Color {
        switch self {
        case .waiting: .cyan
        case .passed: .green
        case .caution: .orange
        case .failed: .red
        case .unknown: .secondary
        }
    }
}

private struct MiniDiagnosticValue: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t(title))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(L10n.t(value))
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .background(
            Color.white.opacity(0.025),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}

private struct DiagnosticsAssessmentSection: View {
    let record: NetworkDiagnosticsRecord

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 360), spacing: 12)
    ]

    var body: some View {
        let operational = InternationalOperationalAssessmentEngine.assess(
            record.targets
        )
        let includesIPAnalysis = record.reputationAssessment != nil
            || record.privacyAssessment != nil

        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: "诊断评分",
                systemImage: "checklist.checked",
                help: "评分只使用本次实际获得的信号。每一项都可展开查看依据；缺失数据会降低完整度和置信度，数据不足时不显示满分。VPN、Hosting 或数据中心属性不会自动等同于恶意。"
            )

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                AssessmentSummaryCard(
                    title: "国际连通评分",
                    symbol: "globe.asia.australia.fill",
                    tint: .cyan,
                    assessment: record.internationalAssessment
                )
                if includesIPAnalysis,
                   let reputation = record.reputationAssessment {
                    AssessmentSummaryCard(
                        title: "IP 信誉评分",
                        symbol: "checkmark.shield.fill",
                        tint: .mint,
                        assessment: reputation
                    )
                }
                if includesIPAnalysis,
                   let privacy = record.privacyAssessment {
                    AssessmentSummaryCard(
                        title: "隐私一致性评分",
                        symbol: "person.badge.shield.checkmark.fill",
                        tint: .indigo,
                        assessment: privacy
                    )
                }
                if includesIPAnalysis {
                    AssessmentSummaryCard(
                        title: "综合网络诊断",
                        symbol: "waveform.path.ecg.rectangle.fill",
                        tint: .blue,
                        assessment: record.combinedAssessment
                    )
                }
                AssessmentSummaryCard(
                    title: "连接稳定度",
                    symbol: "waveform.path.ecg",
                    tint: Color(red: 0.40, green: 0.47, blue: 0.98),
                    assessment: operational.connectionStability,
                    helpMessage: "根据各目标连续有效请求的响应波动评分；10 ms 内为最佳区间，波动越大分数越低。"
                )
                TargetReachabilitySummaryCard(targets: record.targets)
            }

            Label(
                L10n.t("基于当前网络可用信号的评估结果，不代表绝对伪装匿名或身份安全。"),
                systemImage: "info.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .labGlassCard()
    }
}

private struct TargetReachabilitySummaryCard: View {
    let targets: [InternationalTargetResult]
    @State private var showsTargets = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkmark.circle.badge.questionmark.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.green)
                Text(L10n.t("目标可达率"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                InfoHelpButton(
                    title: "目标可达率",
                    message: "显示本轮有多少目标获得了有效 HTTP 响应，并同时统计实际完成的有效请求。单一平台失败不会被直接解释为整个国际网络不可用。"
                )
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(reachabilityPercent.map(String.init) ?? "—")
                    .font(.system(size: 34, weight: .semibold))
                    .monospacedDigit()
                Text("%")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(L10n.t(reachabilityStatus))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(reachabilityTint)
            }

            HStack(spacing: 12) {
                summaryBadge(
                    title: "可访问目标",
                    value: "\(reachableCount) / \(targets.count)"
                )
                summaryBadge(
                    title: "有效请求",
                    value: "\(successfulRequestCount) / \(requestedRequestCount)"
                )
            }

            DisclosureGroup(
                L10n.t("查看目标状态"),
                isExpanded: $showsTargets
            ) {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(targets) { target in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(targetTint(target))
                                .frame(width: 7, height: 7)
                            Text(target.id.displayName)
                            Spacer()
                            Text(
                                L10n.t(
                                    InternationalAssessmentEngine
                                        .targetStatus(target)
                                        .titleKey
                                )
                            )
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .font(.caption.weight(.medium))
            .tint(.green)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .background(
            Color.green.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.green.opacity(0.14), lineWidth: 1)
        }
    }

    private var reachableCount: Int {
        targets.filter { !$0.successfulAttempts.isEmpty }.count
    }

    private var successfulRequestCount: Int {
        targets.reduce(0) { $0 + $1.successfulAttempts.count }
    }

    private var requestedRequestCount: Int {
        targets.reduce(0) { $0 + $1.requestedAttemptCount }
    }

    private var reachabilityPercent: Int? {
        guard !targets.isEmpty else { return nil }
        return Int(
            (Double(reachableCount) / Double(targets.count) * 100).rounded()
        )
    }

    private var reachabilityStatus: String {
        guard !targets.isEmpty else { return "数据不足" }
        if reachableCount == targets.count { return "全部可访问" }
        if reachableCount > 0 { return "部分可访问" }
        return "均无法访问"
    }

    private var reachabilityTint: Color {
        guard !targets.isEmpty else { return .secondary }
        if reachableCount == targets.count { return .green }
        if reachableCount > 0 { return .orange }
        return .red
    }

    private func summaryBadge(title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(L10n.t(title))
                .foregroundStyle(.tertiary)
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.caption2)
    }

    private func targetTint(_ target: InternationalTargetResult) -> Color {
        switch InternationalAssessmentEngine.targetStatus(target) {
        case .good: .green
        case .slow: .yellow
        case .partial: .orange
        case .unavailable: .red
        case .insufficient: .secondary
        }
    }
}

struct AssessmentSummaryCard: View {
    let title: String
    let symbol: String
    let tint: Color
    let assessment: ScoreAssessment
    var helpMessage: String = "分数来自下方可展开的实际信号；完整度表示本轮拿到了多少应有数据，置信度还会考虑数据源数量和证据强弱。"
    @State private var showsBasis = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: symbol)
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                Text(L10n.t(title))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                InfoHelpButton(
                    title: title,
                    message: helpMessage
                )
            }

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(assessment.score.map(String.init) ?? "—")
                    .font(.system(size: 34, weight: .semibold))
                    .monospacedDigit()
                Text("/ 100")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(L10n.t(assessment.grade.titleKey))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(assessment.grade.tint)
            }

            HStack(spacing: 12) {
                assessmentBadge(
                    title: "完整度",
                    value: percent(assessment.completeness)
                )
                assessmentBadge(
                    title: "置信度",
                    value: percent(assessment.confidence)
                )
            }

            DisclosureGroup(
                L10n.t("查看评分依据"),
                isExpanded: $showsBasis
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(assessment.signals) { signal in
                        AssessmentSignalRow(signal: signal)
                    }
                }
                .padding(.top, 8)
            }
            .font(.caption.weight(.medium))
            .tint(tint)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .background(
            tint.opacity(0.055),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(tint.opacity(0.15), lineWidth: 1)
        }
    }

    private func assessmentBadge(title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(L10n.t(title))
                .foregroundStyle(.tertiary)
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.caption2)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

private struct AssessmentSignalRow: View {
    let signal: AssessmentSignal

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: signal.impact.symbol)
                .foregroundStyle(signal.impact.tint)
                .frame(width: 15)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(localizedSignalTitle)
                        .font(.caption.weight(.semibold))
                    if signal.scoreDelta != 0 {
                        Text("\(signal.scoreDelta)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(signal.impact.tint)
                    }
                }
                Text(L10n.t(signal.detailKey))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var localizedSignalTitle: String {
        for target in InternationalTargetID.allCases {
            let prefix = "\(target.displayName)："
            if signal.titleKey.hasPrefix(prefix) {
                let statusKey = String(signal.titleKey.dropFirst(prefix.count))
                return "\(target.displayName)：\(L10n.t(statusKey))"
            }
        }
        return L10n.t(signal.titleKey)
    }
}

private struct InternationalDiagnosticsHistoryCard: View {
    let records: [NetworkDiagnosticsRecord]
    let historyURL: URL
    @State private var currentPage = 0

    private let pageSize = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: "最近国际诊断",
                systemImage: "clock.arrow.circlepath",
                help: "最多保留最近 50 次国际诊断。只保存各目标连接阶段、耗时、评分，以及国家、ASN、网络类型摘要；不保存完整公网 IP、MAC、BSSID、SSID 或私人内容。"
            )

            if records.isEmpty {
                ContentUnavailableView(
                    "还没有国际诊断记录",
                    systemImage: "globe.badge.chevron.backward",
                    description: Text(L10n.t("完成一次国际诊断后，这里会显示最近结论。"))
                )
                .frame(maxWidth: .infinity, minHeight: 130)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(pagedRecords.enumerated()), id: \.element.id) {
                        index,
                        record in
                        InternationalHistoryRow(record: record)
                        if index < pagedRecords.count - 1 {
                            Divider().opacity(0.16)
                        }
                    }
                }
                pager
            }

            Label(
                "\(L10n.t("结果保存于本机"))：\(historyURL.path)",
                systemImage: "lock.shield"
            )
            .font(.caption2)
            .foregroundStyle(Color.primary.opacity(0.38))
            .textSelection(.enabled)
        }
        .labGlassCard()
        .onChange(of: records.first?.id) { _, _ in
            currentPage = 0
        }
    }

    private var pagedRecords: [NetworkDiagnosticsRecord] {
        let page = min(max(0, currentPage), totalPages - 1)
        let start = page * pageSize
        let end = min(start + pageSize, records.count)
        guard start < end else { return [] }
        return Array(records[start..<end])
    }

    private var totalPages: Int {
        max(1, (records.count + pageSize - 1) / pageSize)
    }

    private var pager: some View {
        HStack {
            Text(String(format: L10n.t("共 %d 次"), records.count))
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            Button {
                currentPage = max(0, currentPage - 1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .disabled(currentPage == 0)
            Text(
                String(
                    format: L10n.t("第 %d / %d 页"),
                    currentPage + 1,
                    totalPages
                )
            )
            .font(.caption.weight(.semibold).monospacedDigit())
            .frame(minWidth: 68)
            Button {
                currentPage = min(totalPages - 1, currentPage + 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(currentPage >= totalPages - 1)
        }
        .foregroundStyle(.secondary)
    }
}

private struct InternationalHistoryRow: View {
    let record: NetworkDiagnosticsRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe.asia.australia.fill")
                .foregroundStyle(.cyan)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(
                    record.completedAt.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )
                .font(.callout.weight(.semibold))
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            historyScore(
                title: "国际",
                assessment: record.internationalAssessment,
                tint: .cyan
            )
            historyScore(
                title: "信誉",
                assessment: record.reputationAssessment,
                tint: .mint
            )
            historyScore(
                title: "隐私",
                assessment: record.privacyAssessment,
                tint: .indigo
            )
            historyScore(
                title: "综合",
                assessment: record.combinedAssessment,
                tint: .blue
            )
        }
        .padding(.vertical, 10)
    }

    private var summary: String {
        let accessible = record.targets.filter {
            !$0.successfulAttempts.isEmpty
        }.count
        var components = [
            String(
                format: L10n.t("%d / %d 个目标可访问"),
                accessible,
                record.targets.count
            )
        ]
        if let country = record.publicSummary?.countryCode {
            components.append(country)
        }
        if let asn = record.publicSummary?.asn {
            components.append(asn)
        }
        return components.joined(separator: " · ")
    }

    private func historyScore(
        title: String,
        assessment: ScoreAssessment?,
        tint: Color
    ) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(assessment?.score.map(String.init) ?? "—")
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
            Text(L10n.t(title))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(width: 45)
    }
}

private struct NetworkSheetHeaderMaterial: View {
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    let tint: Color

    var body: some View {
        ZStack {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
            }

            LinearGradient(
                colors: [
                    tint.opacity(0.075),
                    Color.black.opacity(0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct NetworkSheetScrollEdge: View {
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    let tint: Color

    var body: some View {
        ZStack {
            if reduceTransparency {
                LinearGradient(
                    colors: [
                        Color(nsColor: .windowBackgroundColor),
                        Color(nsColor: .windowBackgroundColor).opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(
                            colors: [
                                .black,
                                .black.opacity(0.58),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            LinearGradient(
                colors: [
                    tint.opacity(0.045),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: 20)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct NetworkDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var controller: NetworkDetailsController
    @State private var showsAllLocalAddresses = false

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let local = controller.localSnapshot {
                        pathSection(local)
                        localAddressSection(local)
                        publicEgressSection
                        proxyAndTunnelSection(local)
                        wifiSection(local)
                    } else {
                        ProgressView(L10n.t("正在读取本机网络详情…"))
                            .frame(maxWidth: .infinity, minHeight: 180)
                    }

                    if let error = controller.errorMessage {
                        DiagnosticsNoticeCard(
                            message: error,
                            systemImage: "exclamationmark.triangle.fill",
                            tint: .orange
                        )
                    }
                }
                .padding(20)
                .padding(.top, 92)
            }

            VStack(spacing: 0) {
                sheetHeader
                NetworkSheetScrollEdge(tint: .cyan)
            }
            .zIndex(1)
        }
        .frame(minWidth: 820, idealWidth: 920, minHeight: 680, idealHeight: 760)
        .background(LabBackground())
        .task {
            controller.loadLocal()
        }
        .onDisappear {
            controller.cancel()
        }
    }

    private var sheetHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.cyan.opacity(0.13))
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.cyan)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("网络详情"))
                    .font(.title3.weight(.semibold))
                Text(L10n.t("本机信息直接读取；公网出口仅在你确认后查询。"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Toggle(
                L10n.t("显示敏感信息"),
                isOn: $controller.showsSensitiveInformation
            )
            .toggleStyle(.switch)
            .controlSize(.small)

            Button {
                controller.refreshLocal()
            } label: {
                Label("刷新本机", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(controller.phase.isLoading)

            Button("完成") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(18)
        .background(NetworkSheetHeaderMaterial(tint: .cyan))
    }

    private func pathSection(
        _ snapshot: LocalNetworkDetailsSnapshot
    ) -> some View {
        DetailsSection(
            title: "当前网络路径",
            symbol: "point.3.connected.trianglepath.dotted"
        ) {
            detailsGrid {
                NetworkInfoTile(
                    title: "网络状态",
                    value: snapshot.statusKey,
                    symbol: "checkmark.circle"
                )
                NetworkInfoTile(
                    title: "主要接口类型",
                    value: snapshot.primaryInterfaceTypeKey,
                    symbol: "network"
                )
                NetworkInfoTile(
                    title: "接口名称",
                    value: snapshot.primaryInterfaceName,
                    symbol: "rectangle.connected.to.line.below",
                    monospaced: true
                )
                NetworkInfoTile(
                    title: "网络服务名称",
                    value: snapshot.networkServiceName,
                    symbol: "list.bullet.rectangle"
                )
                NetworkInfoTile(
                    title: "IPv4 / IPv6",
                    value: "\(supported(snapshot.supportsIPv4)) / \(supported(snapshot.supportsIPv6))",
                    symbol: "arrow.left.arrow.right"
                )
                NetworkInfoTile(
                    title: "DNS 支持",
                    value: supported(snapshot.supportsDNS),
                    symbol: "server.rack"
                )
                NetworkInfoTile(
                    title: "受限 / 计费网络",
                    value: "\(yesNo(snapshot.isConstrained)) / \(yesNo(snapshot.isExpensive))",
                    symbol: "gauge.with.dots.needle.33percent"
                )
                SensitiveNetworkInfoTile(
                    title: "默认网关",
                    value: snapshot.defaultGateway,
                    symbol: "door.left.hand.open",
                    style: .ip,
                    showsSensitive: controller.showsSensitiveInformation
                )
                NetworkInfoTile(
                    title: "MTU",
                    value: snapshot.mtu.map(String.init),
                    symbol: "shippingbox"
                )
            }
        }
    }

    private func localAddressSection(
        _ snapshot: LocalNetworkDetailsSnapshot
    ) -> some View {
        let addresses = snapshot.addresses.filter {
            !$0.isLoopback
                && (
                    $0.interfaceName == snapshot.primaryInterfaceName
                        || snapshot.tunnelInterfaces.contains($0.interfaceName)
                )
        }
        let compactAddresses = representativeAddresses(
            addresses,
            primaryInterfaceName: snapshot.primaryInterfaceName
        )
        let visibleAddresses = showsAllLocalAddresses
            ? addresses
            : compactAddresses
        return DetailsSection(
            title: "本机与局域网地址",
            symbol: "laptopcomputer"
        ) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.cyan)
                        .padding(.top, 1)
                    Text(L10n.t("这里显示 macOS 分配给本机接口的局域网与隧道地址；地址默认遮罩，展开后可查看临时 IPv6 和隧道接口。"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 2)

                VStack(spacing: 8) {
                    ForEach(visibleAddresses) { address in
                        LocalAddressRow(
                            address: address,
                            isPrimary: address.interfaceName
                                == snapshot.primaryInterfaceName,
                            showsSensitive: controller.showsSensitiveInformation
                        )
                    }
                }

                detailsGrid {
                    SensitiveNetworkInfoTile(
                        title: "MAC 地址",
                        value: snapshot.macAddress,
                        symbol: "number",
                        style: .mac,
                        showsSensitive: controller.showsSensitiveInformation
                    )
                    SensitiveNetworkInfoTile(
                        title: "DNS 服务器",
                        value: snapshot.dnsServers.isEmpty
                            ? nil
                            : snapshot.dnsServers.joined(separator: ", "),
                        symbol: "server.rack",
                        style: .list,
                        showsSensitive: controller.showsSensitiveInformation
                    )
                    NetworkInfoTile(
                        title: "搜索域",
                        value: snapshot.searchDomains.isEmpty
                            ? nil
                            : snapshot.searchDomains.joined(separator: ", "),
                        symbol: "magnifyingglass"
                    )
                }

                if addresses.count > compactAddresses.count {
                    HStack(spacing: 10) {
                        Button {
                            withAnimation(.snappy(duration: 0.24)) {
                                showsAllLocalAddresses.toggle()
                            }
                        } label: {
                            Label(
                                showsAllLocalAddresses
                                    ? "收起次要地址"
                                    : "显示更多地址",
                                systemImage: showsAllLocalAddresses
                                    ? "chevron.up"
                                    : "chevron.down"
                            )
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Text(L10n.t("默认只显示主要接口的代表地址；临时 IPv6 和隧道地址可按需展开。"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var publicEgressSection: some View {
        DetailsSection(title: "公网出口", symbol: "globe.americas.fill") {
            VStack(alignment: .leading, spacing: 13) {
                if controller.publicSnapshot == nil
                    && controller.phase != .queryingPublic {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.t("公网信息需要主动查询"))
                                .font(.callout.weight(.semibold))
                            Text(L10n.t("查询公网出口时，网络信息查询服务（ipify、ipwho.is 与 proxycheck.io）会接收到当前公网 IP；不会上传硬件数据、历史文件或个人内容。"))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 12)
                        Button {
                            controller.queryPublicAndReputation()
                        } label: {
                            Label("查询公网出口", systemImage: "globe.badge.chevron.backward")
                                .fixedSize()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        .controlSize(.large)
                    }
                    .padding(14)
                    .background(
                        Color.orange.opacity(0.055),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.orange.opacity(0.14), lineWidth: 1)
                    }
                }

                if controller.phase == .queryingPublic {
                    HStack(spacing: 11) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L10n.t("正在查询公网出口与数据来源…"))
                            .font(.callout.weight(.semibold))
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        Color.cyan.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                }

                if let snapshot = controller.publicSnapshot {
                    HStack {
                        Label(
                            L10n.t("已获取公网出口摘要"),
                            systemImage: "checkmark.circle.fill"
                        )
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.mint)
                        Spacer()
                        Button {
                            controller.queryPublicAndReputation()
                        } label: {
                            Label("重新查询公网出口", systemImage: "arrow.clockwise")
                                .fixedSize()
                        }
                        .buttonStyle(.bordered)
                        .disabled(controller.phase == .queryingPublic)
                    }
                    PublicEgressSummaryView(
                        snapshot: snapshot,
                        showsSensitive: controller.showsSensitiveInformation
                    )
                }
            }
        }
    }

    private func representativeAddresses(
        _ addresses: [LocalNetworkAddress],
        primaryInterfaceName: String?
    ) -> [LocalNetworkAddress] {
        let primary = primaryInterfaceName.map { interfaceName in
            addresses.filter { $0.interfaceName == interfaceName }
        } ?? []
        let candidates = primary.isEmpty ? addresses : primary
        var selected: [LocalNetworkAddress] = []

        if let ipv4 = candidates.first(where: { $0.ipVersion == "IPv4" }) {
            selected.append(ipv4)
        }
        let ipv6Candidates = candidates.filter { $0.ipVersion == "IPv6" }
        if let ipv6 = ipv6Candidates.first(where: {
            !$0.address.lowercased().hasPrefix("fe80:")
        }) ?? ipv6Candidates.first {
            selected.append(ipv6)
        }
        return selected
    }

    private func proxyAndTunnelSection(
        _ snapshot: LocalNetworkDetailsSnapshot
    ) -> some View {
        DetailsSection(
            title: "代理与隧道",
            symbol: "shield.lefthalf.filled"
        ) {
            detailsGrid {
                NetworkInfoTile(
                    title: "HTTP 代理",
                    value: proxyValue(
                        enabled: snapshot.proxy.httpEnabled,
                        host: snapshot.proxy.httpHost
                    ),
                    symbol: "network"
                )
                NetworkInfoTile(
                    title: "HTTPS 代理",
                    value: proxyValue(
                        enabled: snapshot.proxy.httpsEnabled,
                        host: snapshot.proxy.httpsHost
                    ),
                    symbol: "lock"
                )
                NetworkInfoTile(
                    title: "SOCKS 代理",
                    value: proxyValue(
                        enabled: snapshot.proxy.socksEnabled,
                        host: snapshot.proxy.socksHost
                    ),
                    symbol: "arrow.triangle.swap"
                )
                NetworkInfoTile(
                    title: "PAC 自动代理",
                    value: proxyValue(
                        enabled: snapshot.proxy.pacEnabled,
                        host: snapshot.proxy.pacURL
                    ),
                    symbol: "doc.text"
                )
                NetworkInfoTile(
                    title: "隧道接口",
                    value: snapshot.tunnelInterfaces.isEmpty
                        ? L10n.t("未检测到")
                        : snapshot.tunnelInterfaces.joined(separator: ", "),
                    symbol: "personalhotspot",
                    monospaced: true
                )
                NetworkInfoTile(
                    title: "疑似 VPN / 系统代理路径",
                    value: yesNo(
                        snapshot.proxy.isAnyEnabled
                            || !snapshot.tunnelInterfaces.isEmpty
                    ),
                    symbol: "lock.shield"
                )
            }
        }
    }

    @ViewBuilder
    private func wifiSection(
        _ snapshot: LocalNetworkDetailsSnapshot
    ) -> some View {
        DetailsSection(title: "Wi‑Fi 信息", symbol: "wifi") {
            if let wifi = snapshot.wifi {
                detailsGrid {
                    NetworkInfoTile(
                        title: "Wi‑Fi 接口状态",
                        value: wifi.powerOn ? L10n.t("已开启") : L10n.t("已关闭"),
                        symbol: "power"
                    )
                    SensitiveNetworkInfoTile(
                        title: "SSID",
                        value: wifi.ssid,
                        symbol: "wifi",
                        style: .name,
                        showsSensitive: controller.showsSensitiveInformation
                    )
                    SensitiveNetworkInfoTile(
                        title: "BSSID",
                        value: wifi.bssid,
                        symbol: "dot.radiowaves.left.and.right",
                        style: .mac,
                        showsSensitive: controller.showsSensitiveInformation
                    )
                    NetworkInfoTile(
                        title: "RSSI / Noise",
                        value: wifi.rssi.map {
                            "\($0) dBm / \(wifi.noise.map(String.init) ?? "—") dBm"
                        },
                        symbol: "wave.3.right"
                    )
                    NetworkInfoTile(
                        title: "信道 / 频段",
                        value: wifi.channel.map {
                            "\($0) · \(wifi.band ?? "—")"
                        },
                        symbol: "waveform.path"
                    )
                    NetworkInfoTile(
                        title: "PHY 模式",
                        value: wifi.phyMode,
                        symbol: "antenna.radiowaves.left.and.right"
                    )
                    NetworkInfoTile(
                        title: "协商速率",
                        value: wifi.transmitRateMbps.map {
                            String(format: "%.0f Mbps", $0)
                        },
                        symbol: "speedometer"
                    )
                    NetworkInfoTile(
                        title: "国家代码",
                        value: wifi.countryCode,
                        symbol: "flag"
                    )
                    NetworkInfoTile(
                        title: "接口模式",
                        value: wifi.interfaceMode,
                        symbol: "macbook.and.iphone"
                    )
                }
                if let note = wifi.privacyRestrictionNote {
                    Label(L10n.t(note), systemImage: "location.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView(
                    "Wi‑Fi 信息不可用",
                    systemImage: "wifi.slash",
                    description: Text(L10n.t("当前没有系统可读的 Wi‑Fi 接口。"))
                )
                .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
    }

    private func detailsGrid<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 225, maximum: 360), spacing: 10)
            ],
            alignment: .leading,
            spacing: 10,
            content: content
        )
    }

    private func supported(_ value: Bool) -> String {
        L10n.t(value ? "支持" : "不支持")
    }

    private func yesNo(_ value: Bool) -> String {
        L10n.t(value ? "是" : "否")
    }

    private func proxyValue(enabled: Bool, host: String?) -> String {
        guard enabled else { return L10n.t("未启用") }
        return host.map { "\(L10n.t("已启用")) · \($0)" } ?? L10n.t("已启用")
    }
}

struct IPIntelligenceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var controller: NetworkDetailsController

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    publicIntelligenceSection

                    if let error = controller.errorMessage {
                        DiagnosticsNoticeCard(
                            message: error,
                            systemImage: "exclamationmark.triangle.fill",
                            tint: .orange
                        )
                    }
                }
                .padding(20)
                .padding(.top, 92)
            }

            VStack(spacing: 0) {
                sheetHeader
                NetworkSheetScrollEdge(tint: .indigo)
            }
            .zIndex(1)
        }
        .frame(minWidth: 820, idealWidth: 920, minHeight: 640, idealHeight: 740)
        .background(LabBackground())
        .task {
            controller.loadLocal()
        }
        .onDisappear {
            controller.cancel()
        }
    }

    private var sheetHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.indigo.opacity(0.24),
                                Color.cyan.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.indigo)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("IP 分析"))
                    .font(.title3.weight(.semibold))
                Text(L10n.t("公网出口、IP 信誉与隐私一致性，由你主动查询。"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Toggle(
                L10n.t("显示敏感信息"),
                isOn: $controller.showsSensitiveInformation
            )
            .toggleStyle(.switch)
            .controlSize(.small)

            if controller.publicSnapshot != nil {
                Button {
                    controller.queryPublicAndReputation()
                } label: {
                    Label("重新查询", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(controller.phase == .queryingPublic)
            }

            Button("完成") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(18)
        .background(NetworkSheetHeaderMaterial(tint: .indigo))
    }

    private var publicIntelligenceSection: some View {
        DetailsSection(
            title: "公网出口与信誉分析",
            symbol: "globe.badge.chevron.backward"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if controller.publicSnapshot == nil
                    && controller.phase != .queryingPublic {
                    HStack(alignment: .center, spacing: 13) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.12))
                            Image(systemName: "hand.raised.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                        .frame(width: 38, height: 38)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.t("查询前隐私说明"))
                                .font(.callout.weight(.semibold))
                            Text(L10n.t("查询公网出口及 IP 信誉时，网络信息查询服务（ipify、ipwho.is 与 proxycheck.io）会接收到当前公网 IP。不会上传本机硬件数据、历史文件或个人内容。"))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 12)
                        Button {
                            controller.queryPublicAndReputation()
                        } label: {
                            Label("同意并查询", systemImage: "shield.checkered")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        .controlSize(.large)
                    }
                    .padding(14)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(0.07),
                                Color.cyan.opacity(0.025)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.orange.opacity(0.16), lineWidth: 1)
                    }

                    IPAnalysisPreview()
                }

                if controller.phase == .queryingPublic {
                    HStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.small)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.t("正在查询公网出口与信誉数据…"))
                                .font(.callout.weight(.semibold))
                            Text(L10n.t("正在比对 IPv4、IPv6、ASN、网络属性与可用风险信号。"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(15)
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .background(Color.cyan.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if let snapshot = controller.publicSnapshot {
                    scoreSummary
                    publicSummary(snapshot)
                    if let risk = snapshot.riskProfile {
                        riskAttributes(risk)
                        riskEvidence(risk)
                    }
                    providerFooter(snapshot)
                }
            }
        }
    }

    private func publicSummary(
        _ snapshot: PublicNetworkIntelligenceSnapshot
    ) -> some View {
        PublicEgressSummaryView(
            snapshot: snapshot,
            showsSensitive: controller.showsSensitiveInformation
        )
    }

    private func riskAttributes(_ risk: IPRiskProfile) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(L10n.t("网络属性与风险信号"))
                .font(.callout.weight(.semibold))
            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 165), spacing: 10),
                    GridItem(.flexible(minimum: 165), spacing: 10),
                    GridItem(.flexible(minimum: 165), spacing: 10),
                    GridItem(.flexible(minimum: 165), spacing: 10)
                ],
                alignment: .leading,
                spacing: 10
            ) {
                RiskAttributePill(title: "VPN", value: risk.isVPN)
                RiskAttributePill(title: "公共代理", value: risk.isProxy)
                RiskAttributePill(title: "Tor", value: risk.isTor)
                RiskAttributePill(title: "匿名网络", value: risk.isAnonymous)
                RiskAttributePill(title: "Hosting", value: risk.isHosting)
                RiskAttributePill(
                    title: "住宅代理",
                    value: risk.isResidentialProxy
                )
                RiskAttributePill(
                    title: "自动化抓取",
                    value: risk.isScraper
                )
                RiskAttributePill(
                    title: "受损风险信号",
                    value: risk.isCompromised,
                    trueIsRisk: true
                )
            }
            Text(L10n.t("以上八项均来自本轮网络信息查询结果；VPN、Hosting 与数据中心属性不会自动判定为低信誉或恶意。Relay 与 Anycast 需要带凭据的专业数据源，当前版本不会用推测代替结论。"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func riskEvidence(_ risk: IPRiskProfile) -> some View {
        detailsGrid {
            NetworkInfoTile(
                title: "供应商风险值",
                value: risk.riskScore.map { "\($0) / 100" },
                symbol: "gauge.with.dots.needle.67percent",
                emptyValue: "未提供风险评分"
            )
            NetworkInfoTile(
                title: "供应商置信度",
                value: risk.providerConfidence.map { "\($0)%" },
                symbol: "checkmark.seal",
                emptyValue: "未提供置信度"
            )
            NetworkInfoTile(
                title: "历史攻击信号",
                value: risk.attackCount.map {
                    $0 == 0 ? L10n.t("未发现攻击记录") : String($0)
                },
                symbol: "exclamationmark.shield",
                emptyValue: "未提供历史记录"
            )
            NetworkInfoTile(
                title: "最近发现风险",
                value: lastRiskSummary(risk),
                symbol: "clock.badge.exclamationmark",
                emptyValue: "未提供时间"
            )
            NetworkInfoTile(
                title: "数据更新时间",
                value: formattedProviderTimestamp(risk.lastUpdated),
                symbol: "arrow.triangle.2.circlepath",
                emptyValue: "未提供时间"
            )
        }
    }

    @ViewBuilder
    private var scoreSummary: some View {
        let columns = [
            GridItem(.adaptive(minimum: 230, maximum: 360), spacing: 12)
        ]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            if let reputation = controller.reputationAssessment {
                AssessmentSummaryCard(
                    title: "IP 信誉评分",
                    symbol: "checkmark.shield.fill",
                    tint: .mint,
                    assessment: reputation
                )
            }
            if let privacy = controller.privacyAssessment {
                AssessmentSummaryCard(
                    title: "隐私一致性评分",
                    symbol: "person.badge.shield.checkmark.fill",
                    tint: .indigo,
                    assessment: privacy
                )
            }
            if let combined = controller.combinedAssessment {
                AssessmentSummaryCard(
                    title: "综合网络诊断",
                    symbol: "waveform.path.ecg.rectangle.fill",
                    tint: .blue,
                    assessment: combined
                )
            }
        }
        Label(
            L10n.t("基于当前网络可用信号的评估结果，不代表绝对伪装匿名或身份安全。"),
            systemImage: "info.circle"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func providerFooter(
        _ snapshot: PublicNetworkIntelligenceSnapshot
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 12) {
                Label(
                    snapshot.checkedAt.formatted(
                        date: .abbreviated,
                        time: .standard
                    ),
                    systemImage: "clock"
                )
                Label(
                    snapshot.historySummary.sources.joined(separator: " · "),
                    systemImage: "server.rack"
                )
            }
            Text(L10n.t("DNS 泄漏未验证：仅读取本机 DNS 地址不能证明泄漏；需要唯一域名与权威 DNS 服务。原生 App 也无法证明所有浏览器不存在 WebRTC 泄漏。"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
    }

    private func detailsGrid<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 225, maximum: 360), spacing: 10)
            ],
            alignment: .leading,
            spacing: 10,
            content: content
        )
    }

    private func supported(_ value: Bool) -> String {
        L10n.t(value ? "支持" : "不支持")
    }

    private func yesNo(_ value: Bool) -> String {
        L10n.t(value ? "是" : "否")
    }

    private func optionalYesNo(_ value: Bool?) -> String? {
        guard let value else { return nil }
        return yesNo(value)
    }

    private func proxyValue(enabled: Bool, host: String?) -> String {
        guard enabled else { return L10n.t("未启用") }
        return host.map { "\(L10n.t("已启用")) · \($0)" } ?? L10n.t("已启用")
    }

    private func formattedProviderTimestamp(_ rawValue: String?) -> String? {
        guard let rawValue, !rawValue.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: rawValue) else { return rawValue }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func lastRiskSummary(_ risk: IPRiskProfile) -> String? {
        if let timestamp = formattedProviderTimestamp(risk.lastSeen) {
            return timestamp
        }
        let hasPositiveSignal = [
            risk.isProxy,
            risk.isTor,
            risk.isCompromised
        ].contains(true)
        if !hasPositiveSignal,
           (risk.riskScore ?? 0) == 0,
           (risk.attackCount ?? 0) == 0 {
            return L10n.t("未发现近期风险")
        }
        return nil
    }
}

private struct LocalAddressRow: View {
    let address: LocalNetworkAddress
    let isPrimary: Bool
    let showsSensitive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(
                systemName: address.ipVersion == "IPv6"
                    ? "6.circle.fill"
                    : "4.circle.fill"
            )
            .font(.title3)
            .foregroundStyle(address.ipVersion == "IPv6" ? .indigo : .cyan)
            .frame(width: 25)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(address.interfaceName)
                        .font(.caption.monospaced().weight(.semibold))
                    Text(address.ipVersion)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if isPrimary {
                        Text(L10n.t("主要接口"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.10), in: Capsule())
                    }
                }

                Text(displayAddress)
                    .font(.body.monospaced().weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 12)

            if let prefixLength = address.cidrPrefixLength {
                Text("/\(prefixLength)")
                    .font(.callout.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.055), in: Capsule())
                    .help(L10n.t("CIDR 网络前缀；例如 /64 等同于常见的 IPv6 子网掩码。"))
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(address.address, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(L10n.t("复制完整值"))
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            LinearGradient(
                colors: [
                    (address.ipVersion == "IPv6" ? Color.indigo : Color.cyan)
                        .opacity(0.075),
                    Color.white.opacity(0.025)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
    }

    private var displayAddress: String {
        showsSensitive
            ? address.address
            : SensitiveValueMasker.mask(address.address, style: .ip)
    }
}

private struct PublicIPAddressCard: View {
    let title: String
    let value: String?
    let symbol: String
    let tint: Color
    let showsSensitive: Bool
    let emptyValue: String

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                Image(systemName: symbol)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(tint)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t(title))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(displayValue)
                    .font(.title3.monospaced().weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 8)

            if let value, !value.isEmpty {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(L10n.t("复制完整值"))
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    tint.opacity(0.105),
                    Color.white.opacity(0.025)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        }
    }

    private var displayValue: String {
        guard let value, !value.isEmpty else { return L10n.t(emptyValue) }
        return showsSensitive
            ? value
            : SensitiveValueMasker.mask(value, style: .ip)
    }
}

private struct PublicEgressSummaryView: View {
    let snapshot: PublicNetworkIntelligenceSnapshot
    let showsSensitive: Bool

    var body: some View {
        let profile = snapshot.preferredProfile
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                PublicIPAddressCard(
                    title: "公网 IPv4",
                    value: snapshot.ipv4Address,
                    symbol: "4.circle.fill",
                    tint: .cyan,
                    showsSensitive: showsSensitive,
                    emptyValue: "未检测到 IPv4 出口"
                )
                PublicIPAddressCard(
                    title: "公网 IPv6",
                    value: snapshot.ipv6Address,
                    symbol: "6.circle.fill",
                    tint: .indigo,
                    showsSensitive: showsSensitive,
                    emptyValue: "未检测到 IPv6 出口"
                )
            }

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 225, maximum: 360), spacing: 10)
                ],
                alignment: .leading,
                spacing: 10
            ) {
                NetworkInfoTile(
                    title: "国家 / 地区",
                    value: [profile?.country, profile?.countryCode]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                        .nilIfEmpty,
                    symbol: "flag",
                    emptyValue: "数据源未提供"
                )
                SensitiveNetworkInfoTile(
                    title: "城市 / 区域",
                    value: [profile?.city, profile?.region]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                        .nilIfEmpty,
                    symbol: "mappin.and.ellipse",
                    style: .location,
                    showsSensitive: showsSensitive,
                    emptyValue: "数据源未提供"
                )
                NetworkInfoTile(
                    title: "ISP",
                    value: profile?.isp ?? snapshot.riskProfile?.provider,
                    symbol: "building.2",
                    emptyValue: "数据源未提供"
                )
                NetworkInfoTile(
                    title: "ASN",
                    value: profile?.asn ?? snapshot.riskProfile?.asn,
                    symbol: "number",
                    emptyValue: "数据源未提供"
                )
                NetworkInfoTile(
                    title: "ASN 组织",
                    value: profile?.asOrganization
                        ?? snapshot.riskProfile?.organization,
                    symbol: "person.3",
                    emptyValue: "数据源未提供"
                )
                NetworkInfoTile(
                    title: "网络类型",
                    value: networkTypeSummary,
                    symbol: "network",
                    emptyValue: "数据源未提供"
                )
                NetworkInfoTile(
                    title: "Anycast",
                    value: snapshot.riskProfile?.isAnycast.map {
                        L10n.t($0 ? "是" : "否")
                    },
                    symbol: "arrow.triangle.branch",
                    emptyValue: "当前来源未覆盖"
                )
                NetworkInfoTile(
                    title: "查询时间",
                    value: snapshot.checkedAt.formatted(
                        date: .abbreviated,
                        time: .standard
                    ),
                    symbol: "clock"
                )
                NetworkInfoTile(
                    title: "数据来源",
                    value: snapshot.historySummary.sources
                        .joined(separator: " · ")
                        .nilIfEmpty,
                    symbol: "server.rack",
                    emptyValue: "数据源未提供"
                )
            }
        }
    }

    private var networkTypeSummary: String? {
        var parts: [String] = []
        if let type = snapshot.riskProfile?.networkType, !type.isEmpty {
            parts.append(type)
        }
        if snapshot.riskProfile?.isHosting == true,
           !parts.contains(where: {
               $0.localizedCaseInsensitiveContains("hosting")
           }) {
            parts.append("Hosting")
        }
        return parts.joined(separator: " · ").nilIfEmpty
    }
}

private struct IPAnalysisPreview: View {
    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 210, maximum: 320), spacing: 10)
            ],
            alignment: .leading,
            spacing: 10
        ) {
            previewItem(
                title: "公网出口",
                detail: "IPv4、IPv6、国家、ASN 与网络类型",
                symbol: "globe.americas.fill",
                tint: .cyan
            )
            previewItem(
                title: "信誉信号",
                detail: "分开呈现 VPN、代理、Hosting 与滥用风险",
                symbol: "checkmark.shield.fill",
                tint: .mint
            )
            previewItem(
                title: "一致性分析",
                detail: "对比双栈出口、地区、时区、代理与隧道",
                symbol: "point.3.filled.connected.trianglepath.dotted",
                tint: .indigo
            )
        }
    }

    private func previewItem(
        title: String,
        detail: String,
        symbol: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.body.weight(.medium))
                .foregroundStyle(tint)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t(title))
                    .font(.callout.weight(.semibold))
                Text(L10n.t(detail))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    tint.opacity(0.055),
                    Color.white.opacity(0.018)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        }
    }
}

private struct DetailsSection<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.cyan.opacity(0.11))
                    Image(systemName: symbol)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.cyan)
                }
                .frame(width: 28, height: 28)
                Text(L10n.t(title))
                    .font(.headline.weight(.semibold))
                Spacer()
            }
            content()
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.055, green: 0.075, blue: 0.105),
                    Color(red: 0.040, green: 0.052, blue: 0.075)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.15),
                            Color.white.opacity(0.075),
                            Color.white.opacity(0.035)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

private struct NetworkInfoTile: View {
    let title: String
    let value: String?
    let symbol: String
    var monospaced = false
    var emptyValue = "不可用"

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t(title))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(L10n.t(value ?? emptyValue))
                    .font(
                        monospaced
                            ? .callout.monospaced().weight(.semibold)
                            : .callout.weight(.semibold)
                    )
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.042),
                    Color.black.opacity(0.055)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
        }
    }
}

private enum SensitiveValueStyle {
    case ip
    case mac
    case name
    case location
    case list
}

private struct SensitiveNetworkInfoTile: View {
    let title: String
    let value: String?
    let symbol: String
    let style: SensitiveValueStyle
    let showsSensitive: Bool
    var emptyValue = "不可用"

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t(title))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(displayValue)
                    .font(.callout.monospaced().weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
            if let value {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(L10n.t("复制完整值"))
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.042),
                    Color.black.opacity(0.055)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
        }
    }

    private var displayValue: String {
        guard let value, !value.isEmpty else { return L10n.t(emptyValue) }
        return showsSensitive ? value : SensitiveValueMasker.mask(value, style: style)
    }
}

private enum SensitiveValueMasker {
    static func mask(_ value: String, style: SensitiveValueStyle) -> String {
        switch style {
        case .ip:
            return maskIP(value)
        case .mac:
            let components = value.split(separator: ":")
            guard components.count >= 4 else { return "••••••" }
            return components.prefix(2).joined(separator: ":") + ":••:••:••:••"
        case .name:
            guard let first = value.first else { return "••••" }
            return "\(first)••••"
        case .location:
            return "•••• · \(L10n.t("已遮罩"))"
        case .list:
            return value
                .split(separator: ",")
                .map { maskIP(String($0).trimmingCharacters(in: .whitespaces)) }
                .joined(separator: ", ")
        }
    }

    private static func maskIP(_ value: String) -> String {
        if value.contains(":") {
            let components = value.split(separator: ":", omittingEmptySubsequences: false)
            return components.prefix(2).joined(separator: ":") + ":••••:••••"
        }
        let components = value.split(separator: ".")
        guard components.count == 4 else { return "••••••" }
        return components.prefix(2).joined(separator: ".") + ".•••.•••"
    }
}

private struct RiskAttributePill: View {
    let title: String
    let value: Bool?
    var trueIsRisk = false

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text(L10n.t(title))
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 8)
            Text(L10n.t(valueText))
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(tint.opacity(0.08), in: Capsule())
        .overlay {
            Capsule().stroke(tint.opacity(0.14), lineWidth: 1)
        }
    }

    private var valueText: String {
        guard let value else { return "未核验" }
        return value ? "检测到" : "未检测到"
    }

    private var tint: Color {
        guard let value else { return .secondary }
        if value {
            return trueIsRisk ? .red : .orange
        }
        return .green
    }

    private var symbol: String {
        guard let value else { return "questionmark.circle" }
        return value
            ? (trueIsRisk ? "exclamationmark.triangle.fill" : "info.circle.fill")
            : "checkmark.circle.fill"
    }
}

private struct DiagnosticsNoticeCard: View {
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(L10n.t(message))
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Spacer()
        }
        .labGlassCard(padding: 14, cornerRadius: 14)
    }
}

private extension InternationalDiagnosticsPhase {
    var systemImage: String {
        switch self {
        case .idle: "globe.asia.australia"
        case .preparing: "network"
        case .probing: "point.3.connected.trianglepath.dotted"
        case .analyzing: "checklist.checked"
        case .completed: "checkmark.circle.fill"
        case .partial: "exclamationmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .cancelled: "stop.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .idle: .secondary
        case .preparing: .mint
        case .probing: .cyan
        case .analyzing: .blue
        case .completed: .green
        case .partial: .orange
        case .failed: .red
        case .cancelled: .secondary
        }
    }
}

private extension AssessmentGrade {
    var tint: Color {
        switch self {
        case .excellent: .green
        case .good: .mint
        case .fair: .yellow
        case .poor: .orange
        case .risk: .red
        case .insufficient: .secondary
        }
    }
}

private extension AssessmentImpact {
    var tint: Color {
        switch self {
        case .positive: .green
        case .informational: .blue
        case .caution: .orange
        case .risk: .red
        case .unavailable: .secondary
        }
    }

    var symbol: String {
        switch self {
        case .positive: "checkmark.circle.fill"
        case .informational: "info.circle.fill"
        case .caution: "exclamationmark.circle.fill"
        case .risk: "exclamationmark.triangle.fill"
        case .unavailable: "questionmark.circle"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
