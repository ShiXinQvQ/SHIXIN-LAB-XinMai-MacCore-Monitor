import AppKit
import Charts
import ShixinStressPowerCore
import SwiftUI
import UniformTypeIdentifiers

struct MonitoringView: View {
    @EnvironmentObject private var appState: AppState
    var onOpenStressTest: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MonitorHeader(onOpenStressTest: onOpenStressTest)
                if let error = appState.lastError {
                    WarningCard(title: "最近错误", message: error, tint: .orange)
                }
                if !appState.helperStatus.isUsable {
                    HelperTelemetryBanner()
                }
                TelemetryMetricGrid()
                RealtimeChartsGrid(samples: appState.liveSession?.samples ?? appState.liveSamples)
                    .equatable()
                TelemetryDetailsCard()
            }
            .padding(22)
        }
    }
}

struct HelperTelemetryBanner: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                icon
                textBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                actionGroup
                    .frame(minWidth: 330, alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    icon
                    textBlock
                }
                actionGroup
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .labGlassCard(padding: 16, cornerRadius: 18)
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(tint.opacity(0.16))
            Image(systemName: appState.helperStatus.needsUpdate ? "arrow.triangle.2.circlepath.circle.fill" : "key.fill")
                .font(.system(size: 28, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
        }
        .frame(width: 54, height: 54)
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.t(appState.helperStatus.needsUpdate ? "Helper 需要更新" : "建议安装 Helper"))
                .font(.headline)
            Text(L10n.t(bannerMessage))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.t(appState.helperStatus.detail))
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .textSelection(.enabled)
        }
    }

    private var actionGroup: some View {
        HStack(spacing: 10) {
            Button {
                appState.showHelperOnboarding()
            } label: {
                Label(L10n.t(appState.helperStatus.needsUpdate ? "查看更新说明" : "查看安装说明"), systemImage: "info.circle")
            }
            .buttonStyle(.bordered)
            .disabled(appState.helperActionInProgress)

            Button {
                appState.installHelper()
            } label: {
                Label(L10n.t(primaryActionTitle), systemImage: "arrow.down.app.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(appState.helperActionInProgress)

            Button {
                appState.refreshHelperStatus()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .help(L10n.t("刷新 Helper 状态"))
            .disabled(appState.helperActionInProgress)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var primaryActionTitle: String {
        if appState.helperActionInProgress {
            return appState.helperStatus.needsUpdate ? "正在更新" : "正在安装"
        }
        return appState.helperStatus.needsUpdate ? "更新 Helper" : "安装 Helper"
    }

    private var bannerMessage: String {
        if appState.helperStatus.needsUpdate {
            return "当前 Helper 仍可提供 powermetrics 采样，但版本或二进制与本 App 内置 Helper 不一致。更新后可确保采样、传感器与修复逻辑来自同一构建。"
        }
        return "安装后可用 root powermetrics 读取功耗、频率与热压。温度、风扇与扩展传感器会优先使用 AppleSMC/HID 本地读取，所有数据只留在本机。"
    }

    private var tint: Color {
        appState.helperStatus.needsUpdate ? .blue : .orange
    }
}

struct MonitorHeader: View {
    @EnvironmentObject private var appState: AppState
    var onOpenStressTest: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            ViewThatFits(in: .horizontal) {
                roomyHeader
                    .frame(minWidth: 980)
                balancedHorizontalHeader
                    .frame(minWidth: 680)
                compactHeader
            }
        }
        .labGlassCard(padding: 16, cornerRadius: 18)
    }

    private var roomyHeader: some View {
        HStack(spacing: 16) {
            titleBlock
                .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(3)
            deviceBlock
                .frame(width: 280, alignment: .trailing)
                .layoutPriority(2)
            actionGroup
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var balancedHorizontalHeader: some View {
        HStack(spacing: 8) {
            titleBlock
                .frame(width: 235, alignment: .leading)
                .layoutPriority(3)
            Spacer(minLength: 0)
            trailingDeviceAndActions(deviceWidth: 235, spacing: 8)
                .layoutPriority(4)
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            titleBlock
            HStack(alignment: .center, spacing: 10) {
                deviceBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                actionGroup
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("SHIXIN LAB · 「芯脉」")
                .font(.title2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text("MacCore Monitor · Stress & Power")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }

    private var deviceBlock: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(deviceModelText)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(sampleStatusText)
                .font(.caption)
                .foregroundStyle(appState.telemetryIsStale ? Color.orange : Color.secondary)
                .lineLimit(1)
        }
        .frame(minWidth: 190, alignment: .trailing)
    }

    private func trailingDeviceAndActions(
        deviceWidth: CGFloat,
        spacing: CGFloat
    ) -> some View {
        HStack(spacing: spacing) {
            deviceBlock
                .frame(width: deviceWidth, alignment: .trailing)
            actionGroup
                .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var actionGroup: some View {
        HStack(spacing: 8) {
            actionButton
            monitorStatusControl
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var monitorStatusControl: some View {
        Label(L10n.t(appState.phase.rawValue), systemImage: appState.phase.symbolName)
            .font(.callout.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(appState.phase.tint)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                appState.phase.tint.opacity(0.09),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(appState.phase.tint.opacity(0.22), lineWidth: 1)
            }
            .fixedSize(horizontal: true, vertical: false)
    }

    private var sampleStatusText: String {
        guard let sample = appState.currentSample else { return L10n.t("等待采样") }
        if appState.telemetryIsStale, let age = appState.telemetryAgeSeconds {
            return "\(L10n.t("采样已延迟")) \(String(format: "%.1f", age)) \(L10n.t("秒"))"
        }
        return "\(L10n.t("最近采样"))：\(Formatters.time(sample.capturedAt))"
    }

    private var deviceModelText: String {
        let modelName = hardwareValue("型号名称") ?? "Mac"
        guard let rawSoC = hardwareValue("SoC"),
              rawSoC != "读取中",
              rawSoC != "未知" else {
            return modelName
        }
        let soc = rawSoC.replacingOccurrences(of: "Apple ", with: "")
        if modelName.localizedCaseInsensitiveContains(soc) {
            return modelName
        }
        return "\(modelName) \(soc)"
    }

    private func hardwareValue(_ title: String) -> String? {
        if let value = appState.hardwareProfile.headlineRows.first(where: { $0.title == title })?.value {
            return value
        }
        for section in appState.hardwareProfile.sections {
            if let value = section.rows.first(where: { $0.title == title })?.value {
                return value
            }
        }
        return nil
    }

    @ViewBuilder
    private var actionButton: some View {
        if appState.phase == .stopping {
            Button {} label: {
                Label("正在停止", systemImage: "hourglass")
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(MonitorHeaderButtonStyle(prominent: false))
            .disabled(true)
        } else if appState.isRunning {
            Button {
                appState.stopStress()
            } label: {
                Label("停止", systemImage: "stop.circle.fill")
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(MonitorHeaderButtonStyle(prominent: false))
        } else {
            Button {
                onOpenStressTest()
            } label: {
                Label("开始烤机", systemImage: "play.circle.fill")
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(MonitorHeaderButtonStyle(prominent: true))
        }
    }
}

private struct MonitorHeaderButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .padding(.horizontal, 11)
            .frame(height: 32)
            .background(
                prominent
                    ? Color.accentColor.opacity(configuration.isPressed ? 0.78 : 1)
                    : Color.white.opacity(configuration.isPressed ? 0.11 : 0.07),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                if !prominent {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
            }
            .opacity(isEnabled ? 1 : 0.48)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct TelemetryMetricGrid: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let sample = appState.currentSample
            let session = appState.liveSession
            let rolling = RollingTelemetrySummary(samples: appState.liveSession?.samples ?? appState.liveSamples, session: session)
            ViewThatFits(in: .horizontal) {
                grid(columns: 4, minWidth: 180, sample: sample, session: session, rolling: rolling)
                grid(columns: 2, minWidth: 190, sample: sample, session: session, rolling: rolling)
            }
        }
    }

    private func grid(columns: Int, minWidth: CGFloat, sample: TelemetrySample?, session: LiveSession?, rolling: RollingTelemetrySummary) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(minimum: minWidth), spacing: 12), count: columns),
            spacing: 12
        ) {
            MetricTile(title: "总/包功耗", value: Formatters.watts(sample?.totalDisplayedPowerW), detail: sample?.source.rawValue ?? "等待 powermetrics", systemImage: "bolt.fill", tint: .yellow)
            MetricTile(title: "CPU 功耗", value: Formatters.watts(sample?.cpuPowerW), detail: activityDetail(sample?.cpuActivePercent), systemImage: "cpu", tint: .green)
            MetricTile(title: "GPU 功耗", value: Formatters.watts(sample?.gpuPowerW), detail: activityDetail(sample?.gpuActivePercent), systemImage: "rectangle.3.group", tint: .blue)
            MetricTile(title: "CPU 温度", value: Formatters.celsius(sample?.cpuTemperatureC), detail: temperatureDetail(sample: sample, count: sample?.cpuTemperatureSensorCount), systemImage: "thermometer.high", tint: .red)
            MetricTile(title: "GPU 温度", value: Formatters.celsius(sample?.gpuTemperatureC), detail: temperatureDetail(sample: sample, count: sample?.gpuTemperatureSensorCount), systemImage: "thermometer.medium", tint: .pink)
            MetricTile(title: "芯片温度", value: Formatters.celsius(sample?.socTemperatureC), detail: socTemperatureDetail(sample: sample), systemImage: "sensor.tag.radiowaves.forward", tint: .teal)
            MetricTile(title: "硬盘温度", value: Formatters.celsius(sample?.diskTemperatureC), detail: sample?.diskTemperatureSourceDetail ?? "等待 SMART", systemImage: "internaldrive", tint: .mint)
            MetricTile(title: "运行时间", value: Formatters.seconds(session?.elapsedSeconds ?? 0), detail: appState.configuration.mode.title, systemImage: "timer", tint: .cyan)
            MetricTile(title: "峰值功耗", value: Formatters.watts(rolling.peakPowerW), detail: rolling.peakDetail, systemImage: "chart.line.uptrend.xyaxis", tint: .orange)
            MetricTile(title: "持续功耗", value: Formatters.watts(rolling.sustainedPower60sW), detail: "60 秒滚动平均", systemImage: "waveform.path.ecg", tint: .purple)
            MetricTile(title: "风扇转速", value: Formatters.rpm(displayFanRPM(sample)), detail: fanDetail(sample: sample), systemImage: "fan", tint: .cyan)
            MetricTile(title: "热状态", value: sample?.thermalState ?? "等待", detail: sample?.thermalPressure ?? "ProcessInfo thermalState", systemImage: "thermometer.medium", tint: (sample?.thermalState ?? "Unknown").thermalTint)
        }
    }

    private func activityDetail(_ percent: Double?) -> String {
        guard percent != nil else { return "等待活跃度" }
        return "活跃度 \(Formatters.percent(percent))"
    }

    private func temperatureDetail(sample: TelemetrySample?, count: Int?) -> String {
        if let count, count > 0 {
            return String(format: L10n.t("AppleSMC 最热点 · %d 个传感器"), count)
        }
        if sample?.cpuTemperatureC != nil || sample?.gpuTemperatureC != nil {
            return sample?.temperatureSourceDetail ?? "温度字段"
        }
        return "等待 HID / powermetrics"
    }

    private func socTemperatureDetail(sample: TelemetrySample?) -> String {
        if let count = sample?.socTemperatureSensorCount, count > 0 {
            return String(format: L10n.t("SoC/PMU · %d 个传感器"), count)
        }
        if sample?.socTemperatureC != nil {
            return sample?.temperatureSourceDetail ?? "芯片温度字段"
        }
        return "独立 CPU/GPU 不可用时显示"
    }

    private func fanDetail(sample: TelemetrySample?) -> String {
        if let fans = sample?.fanRPMs, !fans.isEmpty { return String(format: L10n.t("%d 个风扇"), fans.count) }
        if sample != nil { return "关闭 / 0 RPM" }
        return "等待 AppleSMC"
    }

    private func displayFanRPM(_ sample: TelemetrySample?) -> Double? {
        guard let sample else { return nil }
        return sample.primaryFanRPM ?? 0
    }
}

struct RollingTelemetrySummary {
    var peakPowerW: Double?
    var sustainedPower60sW: Double?
    var estimatedEnergyWh: Double?
    var peakDetail: String
    var energyDetail: String

    init(samples: [TelemetrySample], session: LiveSession?) {
        let recentSamples = Array(samples.suffix(900))
        peakPowerW = session?.peakPowerW ?? recentSamples.compactMap(\.totalDisplayedPowerW).max()
        sustainedPower60sW = session?.sustainedPower60sW ?? Self.rollingAveragePower(samples: recentSamples, windowSeconds: 60)
        estimatedEnergyWh = session?.estimatedEnergyWh ?? Self.energyWh(samples: recentSamples)
        peakDetail = session == nil ? "最近采样峰值" : "Session Peak"
        energyDetail = session == nil ? "最近窗口估算" : "功率积分估算"
    }

    private static func rollingAveragePower(samples: [TelemetrySample], windowSeconds: TimeInterval) -> Double? {
        guard let latest = samples.last?.capturedAt else { return nil }
        let windowStart = latest.addingTimeInterval(-windowSeconds)
        let values = samples
            .filter { $0.capturedAt >= windowStart }
            .compactMap(\.totalDisplayedPowerW)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func energyWh(samples: [TelemetrySample]) -> Double? {
        let points = samples.compactMap { sample -> (Date, Double)? in
            guard let power = sample.totalDisplayedPowerW else { return nil }
            return (sample.capturedAt, power)
        }
        guard points.count >= 2 else { return nil }
        let gapThreshold = TelemetryCurveCompressor.timingSummary(samples: samples).trustedGapThresholdSeconds
        var joules = 0.0
        var coveredSeconds = 0.0
        for index in 1..<points.count {
            let elapsed = points[index].0.timeIntervalSince(points[index - 1].0)
            guard elapsed > 0, elapsed <= gapThreshold else { continue }
            let averagePower = (points[index].1 + points[index - 1].1) / 2
            joules += elapsed * averagePower
            coveredSeconds += elapsed
        }
        guard coveredSeconds > 0 else { return nil }
        return joules / 3600
    }
}

struct LivePowerChart: View {
    var samples: [TelemetrySample]
    var knownGaps: [TelemetrySamplingGap]? = nil
    var sampleLimit: Int? = 360

    private var rows: [TelemetryLineRow] {
        TelemetryChartRows.power(samples, knownGaps: knownGaps, sampleLimit: sampleLimit)
    }

    var body: some View {
        TelemetryLineChartCard(
            title: "实时功耗曲线",
            systemImage: "chart.xyaxis.line",
            help: "显示总功耗、CPU 功耗和 GPU 功耗随时间变化。峰值代表瞬时冲高，持续平台更接近长期稳定烤机功耗。",
            unit: "W",
            rows: rows,
            emptyTitle: "等待可用功耗样本",
            emptySystemImage: "bolt.badge.clock",
            emptyDescription: "没有 root 权限时，powermetrics 功耗曲线会降级为空；压力测试仍可运行。"
        )
    }
}

struct LiveTemperatureChart: View {
    var samples: [TelemetrySample]
    var knownGaps: [TelemetrySamplingGap]? = nil
    var sampleLimit: Int? = 360

    private var rows: [TelemetryLineRow] {
        TelemetryChartRows.coreTemperature(samples, knownGaps: knownGaps, sampleLimit: sampleLimit)
    }

    var body: some View {
        TelemetryLineChartCard(
            title: "实时温度曲线",
            systemImage: "thermometer.variable.and.figure",
            help: "显示 CPU、GPU 和芯片/SoC 温度趋势。这里更关注温度变化方向和最高点，而不是单个传感器的平均值。",
            unit: "°C",
            rows: rows,
            emptyTitle: "等待温度样本",
            emptySystemImage: "thermometer.high",
            emptyDescription: "优先读取 AppleSMC CPU/GPU 温度；若系统未暴露独立传感器，会显示 SoC/PMU 芯片热趋势。"
        )
    }
}

struct LiveFrequencyChart: View {
    var samples: [TelemetrySample]
    var knownGaps: [TelemetrySamplingGap]? = nil
    var sampleLimit: Int? = 360

    private var rows: [TelemetryLineRow] {
        TelemetryChartRows.frequency(samples, knownGaps: knownGaps, sampleLimit: sampleLimit)
    }

    var body: some View {
        TelemetryLineChartCard(
            title: "实时频率曲线",
            systemImage: "speedometer",
            help: "显示 E 核、P 核与 GPU 频率趋势。压力、温度或功耗限制出现时，频率通常会先下降。",
            unit: "MHz",
            rows: rows,
            emptyTitle: "等待频率样本",
            emptySystemImage: "speedometer",
            emptyDescription: "安装或更新 Helper 后，powermetrics 会提供 E 核、P 核与 GPU 频率趋势。"
        )
    }
}

struct LiveActivityChart: View {
    var samples: [TelemetrySample]
    var knownGaps: [TelemetrySamplingGap]? = nil
    var sampleLimit: Int? = 360

    private var rows: [TelemetryLineRow] {
        TelemetryChartRows.activity(samples, knownGaps: knownGaps, sampleLimit: sampleLimit)
    }

    var body: some View {
        TelemetryLineChartCard(
            title: "实时负载曲线",
            systemImage: "gauge.with.dots.needle.67percent",
            help: "显示 CPU/GPU 在采样窗口内的活跃比例。它能帮助判断功耗偏低是因为没有打满，还是因为系统限频或调度策略。",
            unit: "%",
            rows: rows,
            emptyTitle: "等待负载样本",
            emptySystemImage: "gauge.with.dots.needle.67percent",
            emptyDescription: "Helper 可用时，会显示 CPU/GPU active percent 趋势，用于判断压力是否真正打满。",
            yDomain: 0...100
        )
    }
}

struct ModuleTemperatureChart: View {
    var samples: [TelemetrySample]
    var knownGaps: [TelemetrySamplingGap]? = nil
    var sampleLimit: Int? = 360

    private var rows: [TelemetryLineRow] {
        TelemetryChartRows.moduleTemperature(samples, knownGaps: knownGaps, sampleLimit: sampleLimit)
    }

    var body: some View {
        TelemetryLineChartCard(
            title: "机器模块温度曲线",
            systemImage: "sensor.tag.radiowaves.forward",
            help: "显示硬盘、存储芯片热点、Wi-Fi、掌托/环境和气流等模块温度。不同 Mac 暴露的传感器数量会不一样。",
            unit: "°C",
            rows: rows,
            emptyTitle: "等待模块温度样本",
            emptySystemImage: "thermometer.low",
            emptyDescription: "这里会显示硬盘温度、存储芯片热点、Wi-Fi 模块、掌托/环境与气流温度。不同 Mac 和系统版本暴露的传感器会不同。"
        )
    }
}

struct FanRPMChart: View {
    var samples: [TelemetrySample]
    var knownGaps: [TelemetrySamplingGap]? = nil
    var sampleLimit: Int? = 360

    private var rows: [TelemetryLineRow] {
        TelemetryChartRows.fans(samples, knownGaps: knownGaps, sampleLimit: sampleLimit)
    }

    var body: some View {
        TelemetryLineChartCard(
            title: "散热风扇转速曲线",
            systemImage: "fan",
            help: "显示风扇转速随时间变化。低负载时 macOS 可能让风扇停转，0 RPM 是正常散热策略，不代表读取失败。",
            unit: "RPM",
            rows: rows,
            emptyTitle: "等待风扇转速样本",
            emptySystemImage: "fan",
            emptyDescription: "有双风扇时会分别显示左风扇与右风扇；单风扇或无风扇机型会按系统可读结果降级。"
        )
    }
}

struct RealtimeChartsGrid: View, Equatable {
    var samples: [TelemetrySample]

    static func == (lhs: RealtimeChartsGrid, rhs: RealtimeChartsGrid) -> Bool {
        lhs.chartUpdateToken == rhs.chartUpdateToken
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            LazyVGrid(columns: [
                GridItem(.flexible(minimum: 320), spacing: 14),
                GridItem(.flexible(minimum: 320), spacing: 14)
            ], spacing: 14) {
                LivePowerChart(samples: samples)
                LiveTemperatureChart(samples: samples)
                LiveFrequencyChart(samples: samples)
                LiveActivityChart(samples: samples)
                ModuleTemperatureChart(samples: samples)
                FanRPMChart(samples: samples)
            }
            VStack(alignment: .leading, spacing: 14) {
                LivePowerChart(samples: samples)
                LiveTemperatureChart(samples: samples)
                LiveFrequencyChart(samples: samples)
                LiveActivityChart(samples: samples)
                ModuleTemperatureChart(samples: samples)
                FanRPMChart(samples: samples)
            }
        }
    }

    private var chartUpdateToken: Int64 {
        guard let date = samples.last?.capturedAt else { return 0 }
        return Int64(date.timeIntervalSinceReferenceDate.rounded(.down))
    }
}

struct RealtimeCurvesStack: View, Equatable {
    var samples: [TelemetrySample]

    static func == (lhs: RealtimeCurvesStack, rhs: RealtimeCurvesStack) -> Bool {
        lhs.chartUpdateToken == rhs.chartUpdateToken
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LivePowerChart(samples: samples)
            LiveTemperatureChart(samples: samples)
            LiveFrequencyChart(samples: samples)
            LiveActivityChart(samples: samples)
            ModuleTemperatureChart(samples: samples)
            FanRPMChart(samples: samples)
        }
    }

    private var chartUpdateToken: Int64 {
        guard let date = samples.last?.capturedAt else { return 0 }
        return Int64(date.timeIntervalSinceReferenceDate.rounded(.down))
    }
}

struct TelemetryCurveExportButton: View {
    var samples: [TelemetrySample]

    var body: some View {
        Button {
            TelemetryCurveLogExporter.export(samples: samples)
        } label: {
            Label("导出曲线 Log", systemImage: "square.and.arrow.down")
        }
        .buttonStyle(.bordered)
        .disabled(samples.isEmpty)
    }
}

struct TelemetryLineChartCard: View {
    var title: String
    var systemImage: String
    var help: String?
    var unit: String
    var rows: [TelemetryLineRow]
    var emptyTitle: String
    var emptySystemImage: String
    var emptyDescription: String
    var yDomain: ClosedRange<Double>?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title, systemImage: systemImage, help: help)
            if rows.count < 2 {
                ContentUnavailableView(L10n.t(emptyTitle), systemImage: emptySystemImage, description: Text(L10n.t(emptyDescription)))
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                chart
                    .chartLegend(position: .bottom)
                    .frame(height: 220)
                    .accessibilityLabel(L10n.t(title))
                    .accessibilityHint(L10n.t(help ?? emptyDescription))
            }
        }
        .labGlassCard()
    }

    @ViewBuilder
    private var chart: some View {
        if let yDomain {
            lineChart
                .chartYScale(domain: yDomain)
        } else {
            lineChart
        }
    }

    private var lineChart: some View {
        Chart(rows) { row in
            LineMark(
                x: .value("时间", row.date),
                y: .value(unit, row.value),
                series: .value("曲线段", row.seriesIdentifier)
            )
            .interpolationMethod(.linear)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .foregroundStyle(by: .value("指标", row.metric))
        }
    }
}

struct TelemetryLineRow: Identifiable {
    var id: String
    var date: Date
    var metric: String
    var value: Double
    var segment: Int

    var seriesIdentifier: String { "\(metric)#\(segment)" }

    init(sampleID: UUID, date: Date, metric: String, value: Double, segment: Int) {
        self.id = "\(sampleID.uuidString)|\(metric)"
        self.date = date
        self.metric = metric
        self.value = value
        self.segment = segment
    }
}

enum TelemetryChartRows {
    private struct MetricDefinition {
        var name: String
        var value: (TelemetrySample) -> Double?
    }

    static func power(
        _ samples: [TelemetrySample],
        knownGaps: [TelemetrySamplingGap]? = nil,
        sampleLimit: Int? = 360
    ) -> [TelemetryLineRow] {
        rows(samples, definitions: [
            MetricDefinition(name: L10n.t("总功耗"), value: { $0.totalDisplayedPowerW }),
            MetricDefinition(name: "CPU", value: { $0.cpuPowerW }),
            MetricDefinition(name: "GPU", value: { $0.gpuPowerW })
        ], knownGaps: knownGaps, sampleLimit: sampleLimit)
    }

    static func coreTemperature(
        _ samples: [TelemetrySample],
        knownGaps: [TelemetrySamplingGap]? = nil,
        sampleLimit: Int? = 360
    ) -> [TelemetryLineRow] {
        rows(samples, definitions: [
            MetricDefinition(name: "CPU", value: { $0.cpuTemperatureC }),
            MetricDefinition(name: "GPU", value: { $0.gpuTemperatureC }),
            MetricDefinition(name: L10n.t("芯片/SoC"), value: { $0.socTemperatureC })
        ], knownGaps: knownGaps, sampleLimit: sampleLimit)
    }

    static func moduleTemperature(
        _ samples: [TelemetrySample],
        knownGaps: [TelemetrySamplingGap]? = nil,
        sampleLimit: Int? = 360
    ) -> [TelemetryLineRow] {
        rows(samples, definitions: [
            MetricDefinition(name: L10n.t("硬盘温度"), value: { $0.diskTemperatureC }),
            MetricDefinition(name: L10n.t("存储芯片热点"), value: { $0.ssdTemperatureC }),
            MetricDefinition(name: L10n.t("Wi-Fi 模块"), value: { $0.wifiTemperatureC }),
            MetricDefinition(name: L10n.t("掌托/环境"), value: { $0.ambientTemperatureC }),
            MetricDefinition(name: L10n.t("气流"), value: { $0.airflowTemperatureC })
        ], knownGaps: knownGaps, sampleLimit: sampleLimit)
    }

    static func frequency(
        _ samples: [TelemetrySample],
        knownGaps: [TelemetrySamplingGap]? = nil,
        sampleLimit: Int? = 360
    ) -> [TelemetryLineRow] {
        rows(samples, definitions: [
            MetricDefinition(name: L10n.t("E 核"), value: { $0.eClusterFrequencyMHz }),
            MetricDefinition(name: L10n.t("P 核"), value: { $0.pClusterFrequencyMHz }),
            MetricDefinition(name: "GPU", value: { $0.gpuFrequencyMHz })
        ], knownGaps: knownGaps, sampleLimit: sampleLimit)
    }

    static func activity(
        _ samples: [TelemetrySample],
        knownGaps: [TelemetrySamplingGap]? = nil,
        sampleLimit: Int? = 360
    ) -> [TelemetryLineRow] {
        rows(samples, definitions: [
            MetricDefinition(name: "CPU", value: { $0.cpuActivePercent }),
            MetricDefinition(name: "GPU", value: { $0.gpuActivePercent })
        ], knownGaps: knownGaps, sampleLimit: sampleLimit)
    }

    static func fans(
        _ samples: [TelemetrySample],
        knownGaps: [TelemetrySamplingGap]? = nil,
        sampleLimit: Int? = 360
    ) -> [TelemetryLineRow] {
        let selectedSamples = sampleLimit.map { Array(samples.suffix($0)) } ?? samples
        let reportedFanCount = selectedSamples.compactMap { $0.fanRPMs?.count }.max() ?? 0
        let fanCount = max(1, min(4, reportedFanCount))
        let inferredSingleFan = reportedFanCount == 0
        let definitions = (0..<fanCount).map { index in
            MetricDefinition(
                name: fanName(index, inferredSingleFan: inferredSingleFan),
                value: { sample in
                    if let rpms = sample.fanRPMs, rpms.indices.contains(index) {
                        return rpms[index]
                    }
                    return inferredSingleFan && index == 0 ? 0 : nil
                }
            )
        }
        return rows(selectedSamples, definitions: definitions, knownGaps: knownGaps, sampleLimit: nil)
    }

    private static func rows(
        _ samples: [TelemetrySample],
        definitions: [MetricDefinition],
        knownGaps: [TelemetrySamplingGap]? = nil,
        sampleLimit: Int? = 360
    ) -> [TelemetryLineRow] {
        let recent = sampleLimit.map { Array(samples.suffix($0)) } ?? samples
        let inferredGapThreshold = knownGaps == nil
            ? TelemetryCurveCompressor.timingSummary(samples: recent).trustedGapThresholdSeconds
            : nil
        var segments: [String: Int] = [:]
        var lastDates: [String: Date] = [:]
        var result: [TelemetryLineRow] = []

        for sample in recent {
            for definition in definitions {
                guard let value = definition.value(sample), value.isFinite else {
                    if lastDates.removeValue(forKey: definition.name) != nil {
                        segments[definition.name, default: 0] += 1
                    }
                    continue
                }
                if let lastDate = lastDates[definition.name] {
                    let crossesGap: Bool
                    if let knownGaps {
                        crossesGap = knownGaps.contains {
                            $0.startedAt >= lastDate && $0.endedAt <= sample.capturedAt
                        }
                    } else {
                        crossesGap = sample.capturedAt.timeIntervalSince(lastDate) > (inferredGapThreshold ?? 2)
                    }
                    if crossesGap {
                        segments[definition.name, default: 0] += 1
                    }
                }
                let segment = segments[definition.name, default: 0]
                result.append(TelemetryLineRow(
                    sampleID: sample.id,
                    date: sample.capturedAt,
                    metric: definition.name,
                    value: value,
                    segment: segment
                ))
                lastDates[definition.name] = sample.capturedAt
            }
        }
        return result
    }

    private static func fanName(_ index: Int, inferredSingleFan: Bool) -> String {
        if inferredSingleFan { return L10n.t("风扇") }
        switch index {
        case 0: return L10n.t("左风扇")
        case 1: return L10n.t("右风扇")
        default: return "\(L10n.t("风扇")) \(index + 1)"
        }
    }
}

enum TelemetryCurveLogExporter {
    static func export(samples: [TelemetrySample]) {
        let panel = NSSavePanel()
        panel.title = "导出曲线 Log"
        panel.nameFieldStringValue = TelemetryCSVExporter.suggestedFilename(
            startedAt: Date(),
            mode: nil,
            prefix: "shixin-mac-telemetry-curves"
        )
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try TelemetryCSVExporter.write(samples: samples, to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

struct TelemetryDetailsCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            hardwarePanel
            samplingPanel
        }
        .frame(maxWidth: .infinity)
    }

    private var samplingPanel: some View {
        TelemetryDetailPanel(title: "采样与降级状态", systemImage: "stethoscope") {
            TelemetryDetailRow(title: "采样来源", value: samplingSourceText)
            TelemetryDetailRow(title: "权限状态", value: appState.permissionMessage)
            TelemetryDetailRow(title: "温度来源", value: temperatureSourceText)
            TelemetryDetailRow(title: "温度传感器", value: temperatureSensorText)
            TelemetryDetailRow(title: "E 核频率", value: Formatters.mhz(appState.currentSample?.eClusterFrequencyMHz))
            TelemetryDetailRow(title: "P 核频率", value: Formatters.mhz(appState.currentSample?.pClusterFrequencyMHz))
            TelemetryDetailRow(title: "GPU 频率", value: Formatters.mhz(appState.currentSample?.gpuFrequencyMHz))
            TelemetryDetailRow(title: "电源", value: powerText)
        }
    }

    private var hardwarePanel: some View {
        TelemetryDetailPanel(title: "硬件温度与散热", systemImage: "sensor.tag.radiowaves.forward") {
            TelemetryDetailRow(title: "CPU 温度", value: Formatters.celsius(appState.currentSample?.cpuTemperatureC))
            TelemetryDetailRow(title: "GPU 温度", value: Formatters.celsius(appState.currentSample?.gpuTemperatureC))
            TelemetryDetailRow(title: "芯片温度", value: Formatters.celsius(appState.currentSample?.socTemperatureC))
            TelemetryDetailRow(title: "风扇转速", value: Formatters.rpm(detailFanRPM))
            TelemetryDetailRow(title: "硬盘温度", value: Formatters.celsius(appState.currentSample?.diskTemperatureC))
            TelemetryDetailRow(title: "存储芯片热点", value: Formatters.celsius(appState.currentSample?.ssdTemperatureC))
            TelemetryDetailRow(title: "Wi‑Fi 温度", value: Formatters.celsius(appState.currentSample?.wifiTemperatureC))
            TelemetryDetailRow(title: "气流温度", value: Formatters.celsius(appState.currentSample?.airflowTemperatureC))
        }
    }

    private var samplingSourceText: String {
        guard let source = appState.currentSample?.sourceDetail else { return "等待采样" }
        var text = source
        text = text.replacingOccurrences(of: "LaunchDaemon helper ", with: "Helper ")
        text = text.replacingOccurrences(of: "-helper", with: "")
        text = text.replacingOccurrences(of: "powermetrics plist / root direct", with: "root powermetrics")
        text = text.replacingOccurrences(of: " / ", with: " · ")
        return L10n.t(text)
    }

    private var temperatureSourceText: String {
        guard let source = appState.currentSample?.temperatureSourceDetail else {
            return "等待 HID / powermetrics"
        }
        if source.contains("AppleSMC") && source.contains("HID") {
            return "AppleSMC + HID"
        }
        if source.contains("AppleSMC") {
            return "AppleSMC"
        }
        if source.contains("powermetrics") {
            return "powermetrics"
        }
        return L10n.t(source)
    }

    private var powerText: String {
        guard let source = appState.currentSample?.powerSource else { return "未知" }
        var parts = [L10n.t(source.source)]
        if let batteryPercent = source.batteryPercent {
            parts.append("\(batteryPercent)%")
        }
        if source.isCharging == true {
            parts.append(L10n.t("充电中"))
        }
        return parts.joined(separator: " · ")
    }

    private var detailFanRPM: Double? {
        guard let sample = appState.currentSample else { return nil }
        return sample.primaryFanRPM ?? 0
    }

    private var temperatureSensorText: String {
        let cpu = appState.currentSample?.cpuTemperatureSensorCount ?? 0
        let gpu = appState.currentSample?.gpuTemperatureSensorCount ?? 0
        let soc = appState.currentSample?.socTemperatureSensorCount ?? 0
        if cpu == 0 && gpu == 0 && soc == 0 {
            return "未匹配 CPU/GPU/SoC"
        }
        return "CPU \(cpu) · GPU \(gpu) · SoC \(soc)"
    }
}

struct TelemetryDetailPanel<Content: View>: View {
    var title: String
    var systemImage: String
    private let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title, systemImage: systemImage)
            content
        }
        .frame(maxWidth: .infinity, minHeight: 272, maxHeight: 272, alignment: .topLeading)
        .labGlassCard()
    }
}

struct TelemetryDetailRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(L10n.t(title))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                InfoHelpButton(title: title, message: Self.help(for: title))
            }
            Spacer(minLength: 12)
            Text(L10n.t(value))
                .font(.body)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .textSelection(.enabled)
        }
        .font(.callout)
        .padding(.vertical, 3)
    }

    private static func help(for title: String) -> String {
        switch title {
        case "CPU 温度":
            return "CPU 相关温度传感器中的代表值，通常取当前可读 CPU 传感器里的最高点，用来观察处理器热压力。"
        case "GPU 温度":
            return "GPU 相关传感器中的代表值。运行 Metal 压力测试时，这个数值能反映图形核心区域的升温。"
        case "芯片温度":
            return "SoC/PMU 等芯片区域的综合热点温度。Apple Silicon 把 CPU、GPU 和控制器集成在同一颗芯片上，所以它很适合看整颗芯片热状态。"
        case "风扇转速":
            return "当前可读风扇转速。低负载下 macOS 可能让风扇停转，因此 0 RPM 属于正常散热策略。"
        case "硬盘温度":
            return "系统盘 SMART 温度，来自内置硬盘健康读数；它更接近硬盘本体温度。"
        case "存储芯片热点":
            return "AppleSMC 暴露的 NAND/存储区域热点，可能高于硬盘 SMART 温度，代表的是存储芯片附近的热区。"
        case "Wi‑Fi 温度":
            return "无线模块附近的温度，适合观察机身内部非 CPU/GPU 区域的热变化。"
        case "气流温度":
            return "机身内部气流或进出风附近温度，通常用于判断散热环境，不等于芯片热点。"
        case "采样来源":
            return "当前数据从哪里来。Helper 表示由后台特权程序读取，root powermetrics 表示可读取功耗和频率。"
        case "权限状态":
            return "当前 powermetrics 和 Helper 是否具备足够权限。权限不足时，App 会继续显示可读取的数据并明确降级。"
        case "温度来源":
            return "温度数据使用的接口。AppleSMC/HID 可读取更多本机传感器；powermetrics 主要提供功耗、频率和部分系统字段。"
        case "温度传感器":
            return "已匹配到的 CPU、GPU、SoC 温度传感器数量。数量越多，说明当前机型暴露的温度信息越完整。"
        case "E 核频率":
            return "能效核心集群频率，适合观察低功耗核心在压力或后台负载下的工作状态。"
        case "P 核频率":
            return "性能核心集群频率。CPU 烤机、渲染和编译等重负载主要会拉高这部分频率。"
        case "GPU 频率":
            return "GPU 当前频率。Metal 压力测试时可以用它判断图形核心是否保持活跃。"
        case "电源":
            return "当前供电来源和电量状态。接电、充电和电池电量会影响系统功耗策略。"
        default:
            return "这是当前采样中的一项硬件状态，用于辅助判断压力测试期间的功耗、温度或降级情况。"
        }
    }
}

struct WarningCard: View {
    var title: String
    var message: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.t(title), systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(tint)
            Text(L10n.t(message))
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .labGlassCard()
    }
}
