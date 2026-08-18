import Charts
import ShixinStressPowerCore
import SwiftUI

struct NetworkSpeedTestView: View {
    @ObservedObject var controller: NetworkSpeedTestController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var diagnosticsController = InternationalDiagnosticsController()
    @StateObject private var networkDetailsController = NetworkDetailsController()
    @StateObject private var locationAuthorization =
        NetworkLocationAuthorizationController()
    @State private var selectedMode: NetworkTestMode = .standard
    @State private var showsNetworkDetails = false
    @State private var showsIPAnalysis = false
    @State private var showsLocationAccessRationale = false
    @State private var opensNetworkDetailsAfterRationale = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NetworkWorkspaceHeader(
                    selectedMode: $selectedMode,
                    showsIPAnalysis: $showsIPAnalysis,
                    onOpenNetworkDetails: {
                        if locationAuthorization.status == .notDetermined {
                            showsLocationAccessRationale = true
                        } else {
                            showsNetworkDetails = true
                        }
                    }
                )

                if selectedMode == .standard {
                    NetworkSpeedHeroCard(
                        controller: controller,
                        reduceMotion: reduceMotion
                    )

                    if let errorMessage = controller.errorMessage {
                        NetworkSpeedNoticeCard(
                            message: errorMessage,
                            systemImage: "exclamationmark.triangle.fill",
                            tint: .orange
                        )
                    }
                    if let historyWarning = controller.historyWarning {
                        NetworkSpeedNoticeCard(
                            message: historyWarning,
                            systemImage: "externaldrive.badge.exclamationmark",
                            tint: .orange
                        )
                    }

                    NetworkMetricsGrid(
                        result: controller.phase.isRunning ? nil : controller.displayResult,
                        isRunning: controller.phase.isRunning,
                        liveMeasurement: controller.liveMeasurement,
                        liveDownloadMbps: controller.liveDownloadMbps,
                        liveUploadMbps: controller.liveUploadMbps,
                        liveLatencyMilliseconds: controller.liveLatencyMilliseconds,
                        liveJitterMilliseconds: controller.liveJitterMilliseconds
                    )
                    NetworkTestDetailsCard(
                        result: controller.phase.isRunning ? nil : controller.displayResult,
                        liveMeasurement: controller.liveMeasurement,
                        liveDownloadedBytes: controller.liveDownloadedBytes,
                        liveUploadedBytes: controller.liveUploadedBytes,
                        liveTrafficInterfaceName: controller.liveTrafficInterfaceName,
                        phase: controller.phase,
                        elapsedSeconds: controller.elapsedSeconds,
                        historyURL: controller.historyURL
                    )
                    NetworkSpeedHistoryCard(records: controller.history)
                } else {
                    InternationalDiagnosticsView(
                        controller: diagnosticsController,
                        reduceMotion: reduceMotion
                    )
                }
            }
            .padding(22)
        }
        .sheet(isPresented: $showsNetworkDetails) {
            NetworkDetailsSheet(controller: networkDetailsController)
        }
        .sheet(isPresented: $showsIPAnalysis) {
            IPIntelligenceSheet(controller: networkDetailsController)
        }
        .sheet(
            isPresented: $showsLocationAccessRationale,
            onDismiss: {
                if opensNetworkDetailsAfterRationale {
                    opensNetworkDetailsAfterRationale = false
                    showsNetworkDetails = true
                }
            }
        ) {
            NetworkLocationAccessSheet(
                onContinue: {
                    opensNetworkDetailsAfterRationale = true
                    locationAuthorization.requestIfNeeded()
                    showsLocationAccessRationale = false
                },
                onSkip: {
                    opensNetworkDetailsAfterRationale = true
                    showsLocationAccessRationale = false
                }
            )
        }
        .onChange(of: selectedMode) { _, mode in
            if mode == .standard {
                diagnosticsController.cancel()
            } else {
                controller.cancelTest()
            }
        }
        .onChange(of: locationAuthorization.status) { _, status in
            if status == .authorizedAlways, showsNetworkDetails {
                networkDetailsController.refreshLocal()
            }
        }
        .onDisappear {
            diagnosticsController.cancel()
            networkDetailsController.cancel()
        }
    }
}

private struct NetworkLocationAccessSheet: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(Color.cyan.opacity(0.14))
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: "wifi")
                                .font(.system(size: 24, weight: .semibold))
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 11, weight: .bold))
                                .padding(2)
                                .background(
                                    Circle()
                                        .fill(Color(nsColor: .windowBackgroundColor))
                                )
                                .offset(x: 4, y: 4)
                        }
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.cyan)
                    }
                    .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.t("完善 Wi‑Fi 网络识别"))
                            .font(.title2.weight(.semibold))
                            .tracking(-0.2)
                        Text(L10n.t("仅用于补全当前网络的系统级信息"))
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    Label(
                        L10n.t("由 macOS 管理"),
                        systemImage: "lock.shield.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.10))
                    )
                }

                Text(
                    L10n.t(
                        "为显示当前 Wi‑Fi 的名称（SSID）、接入点标识（BSSID）及国家或地区代码，macOS 要求 App 获得“使用期间”的定位权限。"
                    )
                )
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    permissionPoint(
                        systemImage: "hand.tap.fill",
                        title: L10n.t("仅在需要时读取"),
                        detail: L10n.t(
                            "只在你主动打开“网络详情”时读取上述 Wi‑Fi 字段。"
                        ),
                        tint: .cyan
                    )
                    permissionPoint(
                        systemImage: "checkmark.shield.fill",
                        title: L10n.t("隐私边界清晰"),
                        detail: L10n.t(
                            "不会持续定位、保存位置轨迹，也不会上传位置数据。"
                        ),
                        tint: .teal
                    )
                    permissionPoint(
                        systemImage: "checkmark.circle.fill",
                        title: L10n.t("其他功能不受影响"),
                        detail: L10n.t(
                            "暂不授权仍可使用带宽测速、国际网络诊断及其他网络信息。"
                        ),
                        tint: .green
                    )
                }
            }
            .padding(24)

            Divider()
                .opacity(0.22)

            HStack(spacing: 10) {
                Spacer()

                Button(L10n.t("暂不授权"), action: onSkip)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)

                Button(action: onContinue) {
                    Label(
                        L10n.t("继续授权"),
                        systemImage: "arrow.right.circle.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.cyan)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(.ultraThinMaterial)
        }
        .frame(width: 560)
        .background(LabBackground())
    }

    private func permissionPoint(
        systemImage: String,
        title: String,
        detail: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(0.12))
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
    }
}

enum NetworkTestMode: String, CaseIterable, Identifiable {
    case standard
    case international

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .standard: "标准网络测速"
        case .international: "国际网络诊断"
        }
    }
}

private struct NetworkWorkspaceHeader: View {
    @Binding var selectedMode: NetworkTestMode
    @Binding var showsIPAnalysis: Bool
    let onOpenNetworkDetails: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 18) {
                titleBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                controls
                    .fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: 14) {
                titleBlock
                controls
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .labGlassCard(padding: 16, cornerRadius: 18)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(L10n.t("网速测试"))
                .font(.title2.weight(.semibold))
                .lineLimit(1)
            Text(L10n.t("带宽性能、国际连通与IP环境纯净度综合诊断"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            Picker("测试模式", selection: $selectedMode) {
                ForEach(NetworkTestMode.allCases) { mode in
                    Text(L10n.t(mode.titleKey)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize(horizontal: true, vertical: false)

            Spacer()
                .frame(width: 14)

            Button {
                onOpenNetworkDetails()
            } label: {
                Label("网络详情", systemImage: "network")
                    .lineLimit(1)
                    .fixedSize()
            }
            .buttonStyle(.bordered)
            .help(L10n.t("查看当前网络路径、本机接口、代理、隧道与 Wi‑Fi 信息。"))

            Spacer()
                .frame(width: 7)

            Button {
                showsIPAnalysis = true
            } label: {
                Label("IP 分析", systemImage: "shield.lefthalf.filled")
                    .lineLimit(1)
                    .fixedSize()
            }
            .buttonStyle(.bordered)
            .help(L10n.t("主动查询公网出口、IP 信誉与隐私一致性。"))
        }
    }
}

private struct NetworkSpeedHeroCard: View {
    @ObservedObject var controller: NetworkSpeedTestController
    let reduceMotion: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 28) {
                progressRing
                heroContent
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Spacer()
                    progressRing
                    Spacer()
                }
                heroContent
            }
        }
        .labGlassCard(padding: 20, cornerRadius: 20)
    }

    private var heroContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 5) {
                Text("标准网络测速")
                    .font(.title2.weight(.semibold))
                InfoHelpButton(
                    title: "标准网络测速",
                    message: "使用 macOS 自带的 networkQuality 测量下载、上传和负载响应能力，并以 7 次低流量 HTTPS 往返计算空闲延迟与抖动。测试只会在你主动开始后联网，不读取或保存公网 IP、SSID、管理员密码；结果仅保存在本机。"
                )
                .font(.body)
                .frame(width: 18, height: 20, alignment: .center)
                Spacer(minLength: 18)
                StatusPill(
                    text: controller.phase.title,
                    systemImage: controller.phase.systemImage,
                    tint: controller.phase.tint
                )
            }

            Text("下载、上传、延迟、抖动与网络负载响应能力，一次搞定。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if controller.phase.isRunning {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: controller.progress)
                        .progressViewStyle(.linear)
                        .tint(.cyan)
                    HStack {
                        Text(L10n.t(controller.phase.title))
                        Spacer()
                        Text("\(Int((controller.progress * 100).rounded()))% · \(elapsedText)")
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(L10n.t("测试进度"))
                .accessibilityValue("\(Int((controller.progress * 100).rounded()))%")
            } else if let result = controller.displayResult {
                HStack(spacing: 14) {
                    Label(
                        result.completedAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "clock"
                    )
                    Label(
                        result.interfaceName ?? L10n.t("系统自动选择"),
                        systemImage: "network"
                    )
                    if let rpm = result.responsivenessRPM {
                        Label("\(rpm) RPM", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text("准备好后开始测试，通常需要 15–35 秒。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    testActionButton
                    trafficNotice
                }
                VStack(alignment: .leading, spacing: 8) {
                    testActionButton
                    trafficNotice
                }
            }
        }
    }

    @ViewBuilder
    private var testActionButton: some View {
        if controller.phase.isRunning {
            Button {
                controller.cancelTest()
            } label: {
                Label("停止测试", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        } else {
            Button {
                controller.startTest()
            } label: {
                Label(
                    controller.phase == .completed ? "重新测试" : "开始测速",
                    systemImage: "speedometer"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.10, green: 0.52, blue: 0.94))
            .keyboardShortcut(.return, modifiers: [.command, .shift])
        }
    }

    private var trafficNotice: some View {
        Text("会产生实际下载与上传流量；App 不在后台自动测速。")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 11)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    AngularGradient(
                        colors: [.cyan, .blue, .cyan],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 11, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(
                    reduceMotion ? nil : .snappy(duration: 0.32, extraBounce: 0),
                    value: ringProgress
                )

            VStack(spacing: 7) {
                Image(systemName: controller.phase.systemImage)
                    .font(.system(size: 29, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(controller.phase.tint)
                if controller.phase.isRunning {
                    Text("\(Int((controller.progress * 100).rounded()))%")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                } else if let result = controller.displayResult {
                    Text("\(String(format: "%.0f", result.downloadMbps))")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    Text("Mbps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("就绪")
                        .font(.headline)
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
        return controller.displayResult == nil ? 0.025 : 1
    }

    private var elapsedText: String {
        let seconds = Int(controller.elapsedSeconds.rounded(.down))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct NetworkMetricsGrid: View {
    let result: NetworkSpeedTestRecord?
    let isRunning: Bool
    let liveMeasurement: NetworkQualityLiveMeasurement?
    let liveDownloadMbps: Double?
    let liveUploadMbps: Double?
    let liveLatencyMilliseconds: Double?
    let liveJitterMilliseconds: Double?

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 260), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            NetworkMetricCard(
                title: "下载速度",
                value: metricValue(downloadMbps),
                unit: downloadMbps == nil ? nil : "Mbps",
                detail: "接收数据的带宽能力",
                systemImage: "arrow.down.circle.fill",
                tint: .cyan,
                help: "下载速度表示网络从测速服务接收数据的能力，单位 Mbps。它会受到 Wi‑Fi 信号、路由器、运营商、服务器距离和同时用网设备影响。"
            )
            NetworkMetricCard(
                title: "上传速度",
                value: metricValue(uploadMbps),
                unit: uploadMbps == nil ? nil : "Mbps",
                detail: "发送数据的带宽能力",
                systemImage: "arrow.up.circle.fill",
                tint: .blue,
                help: "上传速度表示网络向测速服务发送数据的能力，单位 Mbps。视频会议、云盘同步和发送大文件会明显依赖它。"
            )
            NetworkMetricCard(
                title: "空闲延迟",
                value: metricValue(latencyMilliseconds),
                unit: latencyMilliseconds == nil ? nil : "ms",
                detail: "网络空闲时的往返时间",
                systemImage: "timer",
                tint: .mint,
                help: "空闲延迟是网络未被大量占用时的一次往返耗时，越低越好。实际视频会议与游戏体验还要结合抖动和负载响应能力。"
            )
            NetworkMetricCard(
                title: "抖动",
                value: metricValue(jitterMilliseconds),
                unit: jitterMilliseconds == nil ? nil : "ms",
                detail: "连续往返时间的波动",
                systemImage: "waveform.path",
                tint: .orange,
                help: "抖动使用 7 次低流量 HTTPS 往返的相邻延迟差绝对值平均计算，越低越稳定。网络限制探测时会显示不可用，不会用估算值冒充结果。"
            )
            NetworkMetricCard(
                title: "负载响应",
                value: responsivenessRPM.map(String.init) ?? unavailableValue,
                unit: responsivenessRPM == nil ? nil : "RPM",
                detail: "网络忙碌时的响应能力",
                systemImage: "arrow.triangle.2.circlepath.circle.fill",
                tint: .indigo,
                help: "负载响应表示网络在下载与上传都很忙时，每分钟仍能完成多少次有效往返，单位 RPM，通常越高越好。它能补充说明视频会议、远程桌面和游戏在占满带宽时是否仍然跟手。"
            )
        }
    }

    private var downloadMbps: Double? {
        isRunning
            ? liveDownloadMbps ?? liveMeasurement?.downloadMbps
            : result?.downloadMbps
    }

    private var uploadMbps: Double? {
        isRunning
            ? liveUploadMbps ?? liveMeasurement?.uploadMbps
            : result?.uploadMbps
    }

    private var latencyMilliseconds: Double? {
        if isRunning {
            return liveMeasurement?.latencyMilliseconds ?? liveLatencyMilliseconds
        }
        return result?.latencyMilliseconds
    }

    private var jitterMilliseconds: Double? {
        isRunning ? liveJitterMilliseconds : result?.jitterMilliseconds
    }

    private var responsivenessRPM: Int? {
        isRunning ? liveMeasurement?.responsivenessRPM : result?.responsivenessRPM
    }

    private var unavailableValue: String {
        isRunning ? L10n.t("测量中") : "—"
    }

    private func metricValue(_ value: Double?) -> String {
        guard let value else { return unavailableValue }
        return String(format: "%.1f", value)
    }
}

private struct NetworkMetricCard: View {
    let title: String
    let value: String
    let unit: String?
    let detail: String
    let systemImage: String
    let tint: Color
    let help: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                Spacer()
                InfoHelpButton(title: title, message: help)
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(.system(size: 30, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Text(L10n.t(title))
                .font(.subheadline.weight(.semibold))
            Text(L10n.t(detail))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .labGlassCard(padding: 15, cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }
}

private struct NetworkTestDetailsCard: View {
    let result: NetworkSpeedTestRecord?
    let liveMeasurement: NetworkQualityLiveMeasurement?
    let liveDownloadedBytes: Int64?
    let liveUploadedBytes: Int64?
    let liveTrafficInterfaceName: String?
    let phase: NetworkSpeedTestPhase
    let elapsedSeconds: TimeInterval
    let historyURL: URL

    private let columns = [
        GridItem(.adaptive(minimum: 230, maximum: 420), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: "测试详情",
                systemImage: "network.badge.shield.half.filled",
                help: "默认采用 macOS 自带的 networkQuality：不捆绑第三方测速二进制，也不需要 Helper 或管理员权限。带宽与负载响应能力由系统测量；历史只保存数值、时间和网络接口名，不保存公网 IP、SSID 或运营商身份。"
            )

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                NetworkDetailItem(
                    title: "测速引擎",
                    value: result?.engineName ?? "macOS networkQuality",
                    systemImage: "apple.logo"
                )
                NetworkDetailItem(
                    title: "测速服务",
                    value: serviceDisplayName,
                    systemImage: "server.rack",
                    localizesValue: false
                )
                NetworkDetailItem(
                    title: "网络接口",
                    value: liveMeasurement?.interfaceName
                        ?? liveTrafficInterfaceName
                        ?? result?.interfaceName
                        ?? "系统自动选择",
                    systemImage: "network"
                )
                NetworkDetailItem(
                    title: "负载响应能力",
                    value: responsivenessText,
                    systemImage: "arrow.triangle.2.circlepath"
                )
                NetworkDetailItem(
                    title: "测试用时",
                    value: durationText,
                    systemImage: "stopwatch"
                )
                NetworkDetailItem(
                    title: "测试流量",
                    value: transferredText,
                    systemImage: "arrow.up.arrow.down"
                )
            }

            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(Color.primary.opacity(0.38))
                Text("\(L10n.t("结果保存于本机"))：\(historyURL.path)")
                    .foregroundStyle(Color.primary.opacity(0.38))
            }
            .font(.caption)
        }
        .labGlassCard()
    }

    private var responsivenessText: String {
        if phase.isRunning {
            guard let rpm = liveMeasurement?.responsivenessRPM else {
                return L10n.t("测量中")
            }
            let down = liveMeasurement?.downlinkResponsivenessRPM.map(String.init) ?? "—"
            let up = liveMeasurement?.uplinkResponsivenessRPM.map(String.init) ?? "—"
            return "\(rpm) RPM · ↓ \(down) / ↑ \(up)"
        }
        guard let result else {
            return "—"
        }
        guard let rpm = result.responsivenessRPM else { return "—" }
        let down = result.downlinkResponsivenessRPM.map(String.init) ?? "—"
        let up = result.uplinkResponsivenessRPM.map(String.init) ?? "—"
        return "\(rpm) RPM · ↓ \(down) / ↑ \(up)"
    }

    private var durationText: String {
        if phase.isRunning {
            return String(format: "%.1f s", elapsedSeconds)
        }
        guard let result else {
            return "—"
        }
        return String(format: "%.1f s", result.durationSeconds)
    }

    private var transferredText: String {
        if phase.isRunning {
            return transferredText(
                downloadedBytes: liveDownloadedBytes
                    ?? liveMeasurement?.downloadedBytes,
                uploadedBytes: liveUploadedBytes
                    ?? liveMeasurement?.uploadedBytes
            )
        }
        guard let result else {
            return "—"
        }
        return transferredText(
            downloadedBytes: result.downloadedBytes,
            uploadedBytes: result.uploadedBytes
        )
    }

    private func transferredText(
        downloadedBytes: Int64?,
        uploadedBytes: Int64?
    ) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let downloaded = downloadedBytes.map {
            formatter.string(fromByteCount: $0)
        } ?? "—"
        let uploaded = uploadedBytes.map {
            formatter.string(fromByteCount: $0)
        } ?? "—"
        return "↓ \(downloaded) · ↑ \(uploaded)"
    }

    private var serviceDisplayName: String {
        let serviceName = liveMeasurement?.testEndpointHost ?? result?.serverName
        guard let serviceName,
              !serviceName.isEmpty,
              serviceName != "macOS 默认网络质量服务" else {
            return "macOS Default Network Quality Service"
        }
        return serviceName
    }
}

private struct NetworkDetailItem: View {
    let title: String
    let value: String
    let systemImage: String
    var localizesValue = true

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t(title))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(localizesValue ? L10n.t(value) : value)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct NetworkSpeedHistoryCard: View {
    let records: [NetworkSpeedTestRecord]
    @State private var currentPage = 0

    private let pageSize = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: "最近测速",
                systemImage: "clock.arrow.circlepath",
                help: "最多保留最近 50 次网速测试，仅写入本机独立的 JSON 历史。图表用于比较同一网络在不同时间的变化，不代表运营商承诺速率。下方记录每页显示 5 次。"
            )

            if records.isEmpty {
                ContentUnavailableView(
                    "还没有网速记录",
                    systemImage: "speedometer",
                    description: Text("完成一次测速后，这里会显示趋势与最近结果。")
                )
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                speedChart
                Divider().opacity(0.2)
                VStack(spacing: 0) {
                    ForEach(Array(pagedRecords.enumerated()), id: \.element.id) { index, record in
                        NetworkSpeedHistoryRow(record: record)
                        if index < pagedRecords.count - 1 {
                            Divider().opacity(0.16)
                        }
                    }
                }
                historyPager
            }
        }
        .labGlassCard()
        .onChange(of: records.first?.id) { _, _ in
            currentPage = 0
        }
        .onChange(of: records.count) { _, _ in
            currentPage = min(currentPage, totalPages - 1)
        }
    }

    private var totalPages: Int {
        max(1, (records.count + pageSize - 1) / pageSize)
    }

    private var pagedRecords: [NetworkSpeedTestRecord] {
        let safePage = min(max(0, currentPage), totalPages - 1)
        let start = safePage * pageSize
        let end = min(start + pageSize, records.count)
        guard start < end else { return [] }
        return Array(records[start..<end])
    }

    private var historyPager: some View {
        HStack(spacing: 10) {
            Text(String(format: L10n.t("共 %d 次"), records.count))
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            HStack(spacing: 5) {
                pagerButton(
                    systemImage: "chevron.left",
                    help: "上一页",
                    disabled: currentPage == 0
                ) {
                    currentPage = max(0, currentPage - 1)
                }

                Text(
                    String(
                        format: L10n.t("第 %d / %d 页"),
                        currentPage + 1,
                        totalPages
                    )
                )
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 68)

                pagerButton(
                    systemImage: "chevron.right",
                    help: "下一页",
                    disabled: currentPage >= totalPages - 1
                ) {
                    currentPage = min(totalPages - 1, currentPage + 1)
                }
            }
            .padding(4)
            .background(
                Color.white.opacity(0.035),
                in: Capsule(style: .continuous)
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .padding(.top, 2)
    }

    private func pagerButton(
        systemImage: String,
        help: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? Color.secondary.opacity(0.32) : Color.cyan)
        .disabled(disabled)
        .help(L10n.t(help))
    }

    private var speedChart: some View {
        let chartRecords = Array(records.prefix(12).reversed())
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                chartLegend(title: "下载", tint: .cyan)
                chartLegend(title: "上传", tint: .blue)
                Spacer()
                Text("Mbps")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Chart {
                ForEach(chartRecords) { record in
                    LineMark(
                        x: .value("时间", record.completedAt),
                        y: .value("下载 Mbps", record.downloadMbps),
                        series: .value("方向", "下载")
                    )
                    .foregroundStyle(.cyan)
                    .interpolationMethod(.linear)
                    PointMark(
                        x: .value("时间", record.completedAt),
                        y: .value("下载 Mbps", record.downloadMbps)
                    )
                    .foregroundStyle(.cyan)
                    .symbolSize(22)

                    LineMark(
                        x: .value("时间", record.completedAt),
                        y: .value("上传 Mbps", record.uploadMbps),
                        series: .value("方向", "上传")
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.linear)
                    PointMark(
                        x: .value("时间", record.completedAt),
                        y: .value("上传 Mbps", record.uploadMbps)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(22)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine().foregroundStyle(.white.opacity(0.05))
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine().foregroundStyle(.white.opacity(0.07))
                    AxisValueLabel()
                }
            }
            .frame(height: 210)
        }
    }

    private func chartLegend(title: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            Text(L10n.t(title))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct NetworkSpeedHistoryRow: View {
    let record: NetworkSpeedTestRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "speedometer")
                .foregroundStyle(.cyan)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.completedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.callout.weight(.semibold))
                Text(record.interfaceName ?? L10n.t("系统自动选择"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            historyMetric(symbol: "arrow.down", value: "\(format(record.downloadMbps)) Mbps", tint: .cyan)
            historyMetric(symbol: "arrow.up", value: "\(format(record.uploadMbps)) Mbps", tint: .blue)
            historyMetric(symbol: "timer", value: "\(format(record.latencyMilliseconds)) ms", tint: .mint)
            historyMetric(
                symbol: "waveform.path",
                value: record.jitterMilliseconds.map { "\(format($0)) ms" } ?? "—",
                tint: .orange
            )
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func historyMetric(symbol: String, value: String, tint: Color) -> some View {
        Label {
            Text(value)
                .monospacedDigit()
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(tint)
        }
        .font(.caption)
        .lineLimit(1)
    }

    private func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

private struct NetworkSpeedNoticeCard: View {
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

private extension NetworkSpeedTestPhase {
    var systemImage: String {
        switch self {
        case .idle: "speedometer"
        case .preparing: "timer"
        case .measuring: "arrow.up.arrow.down.circle.fill"
        case .analyzing: "waveform.badge.magnifyingglass"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .idle: .secondary
        case .preparing: .mint
        case .measuring: .cyan
        case .analyzing: .blue
        case .completed: .green
        case .failed: .orange
        }
    }
}
