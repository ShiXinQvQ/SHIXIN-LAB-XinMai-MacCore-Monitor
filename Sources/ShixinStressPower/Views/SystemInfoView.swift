import ShixinStressPowerCore
import SwiftUI

struct SystemInfoView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SystemInfoHeader()
                SystemHeadlineGrid(profile: appState.hardwareProfile)
                SystemDetailSectionsView(sections: appState.hardwareProfile.sections)
                if let message = appState.hardwareProfile.message {
                    WarningCard(title: "本机配置读取提示", message: message, tint: .orange)
                }
            }
            .padding(22)
        }
    }
}

struct SystemInfoHeader: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                titleBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    appState.refreshHardwareProfile()
                } label: {
                    Label("刷新配置", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            VStack(alignment: .leading, spacing: 14) {
                titleBlock
                Button {
                    appState.refreshHardwareProfile()
                } label: {
                    Label("刷新配置", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .labGlassCard(padding: 16, cornerRadius: 18)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("本机配置")
                .font(.title2.weight(.semibold))
                .lineLimit(1)
            Text("系统、芯片、图形、内存、存储与设备标识概览")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }
}

struct SystemHeadlineGrid: View {
    var profile: HardwareProfile

    var body: some View {
        ViewThatFits(in: .horizontal) {
            grid(columns: 4, minWidth: 180)
            grid(columns: 2, minWidth: 190)
        }
    }

    private func grid(columns: Int, minWidth: CGFloat) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(minimum: minWidth), spacing: 12), count: columns),
            spacing: 12
        ) {
            ForEach(profile.headlineRows.prefix(4)) { row in
                HardwareMetricTile(row: row, tint: tint(for: row.systemImage))
            }
        }
    }

    private func tint(for systemImage: String) -> Color {
        switch systemImage {
        case "cpu": .green
        case "rectangle.3.group": .blue
        case "memorychip": .purple
        default: .cyan
        }
    }
}

struct HardwareInfoSectionCard: View {
    var section: HardwareInfoSection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: section.title, systemImage: section.systemImage)
            ForEach(section.rows) { row in
                HardwareInfoRowView(row: row)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .labGlassCard()
    }
}

struct SystemDetailSectionsView: View {
    var sections: [HardwareInfoSection]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 14) {
                detailColumn(leftSections)
                detailColumn(rightSections)
            }
            VStack(alignment: .leading, spacing: 14) {
                ForEach(sections) { section in
                    HardwareInfoSectionCard(section: section)
                }
            }
        }
    }

    private var leftSections: [HardwareInfoSection] {
        splitSections.left
    }

    private var rightSections: [HardwareInfoSection] {
        splitSections.right
    }

    private var splitSections: (left: [HardwareInfoSection], right: [HardwareInfoSection]) {
        let leftNames = ["系统软件信息", "处理器与内存", "隐私与设备标识"]
        let rightNames = ["系统硬件信息", "图形与显示", "内置存储"]
        var used = Set<String>()
        var left = preferredSections(leftNames, used: &used)
        var right = preferredSections(rightNames, used: &used)

        for section in sections where !used.contains(section.title) {
            if left.count <= right.count {
                left.append(section)
            } else {
                right.append(section)
            }
            used.insert(section.title)
        }

        return (left, right)
    }

    private func preferredSections(_ names: [String], used: inout Set<String>) -> [HardwareInfoSection] {
        names.compactMap { name in
            guard let section = sections.first(where: { $0.title == name }) else { return nil }
            used.insert(section.title)
            return section
        }
    }

    private func detailColumn(_ sections: [HardwareInfoSection]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(sections) { section in
                HardwareInfoSectionCard(section: section)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct SystemDataOverviewSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let sample = appState.currentSample
            let session = appState.liveSession
            let rolling = RollingTelemetrySummary(samples: appState.liveSession?.samples ?? appState.liveSamples, session: session)
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "数据概览",
                    systemImage: "square.grid.3x3",
                    help: "汇总当前功耗、温度、风扇、频率、热状态与最近窗口统计。数值来自不同系统采样源，更新节奏可能不同；需要连续趋势时请前往实时曲线。"
                )
                ViewThatFits(in: .horizontal) {
                    grid(columns: 4, minWidth: 180, sample: sample, session: session, rolling: rolling)
                    grid(columns: 3, minWidth: 180, sample: sample, session: session, rolling: rolling)
                    grid(columns: 2, minWidth: 180, sample: sample, session: session, rolling: rolling)
                }
            }
        }
    }

    private func grid(columns: Int, minWidth: CGFloat, sample: TelemetrySample?, session: LiveSession?, rolling: RollingTelemetrySummary) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(minimum: minWidth), spacing: 12), count: columns),
            spacing: 12
        ) {
            MetricTile(title: "总/包功耗", value: Formatters.watts(sample?.totalDisplayedPowerW), detail: sample?.source.rawValue ?? "等待采样", systemImage: "bolt.fill", tint: .yellow)
            MetricTile(title: "CPU 功耗", value: Formatters.watts(sample?.cpuPowerW), detail: activityDetail(sample?.cpuActivePercent), systemImage: "cpu", tint: .green)
            MetricTile(title: "GPU 功耗", value: Formatters.watts(sample?.gpuPowerW), detail: activityDetail(sample?.gpuActivePercent), systemImage: "rectangle.3.group", tint: .blue)
            MetricTile(title: "峰值功耗", value: Formatters.watts(rolling.peakPowerW), detail: rolling.peakDetail, systemImage: "chart.line.uptrend.xyaxis", tint: .orange)

            MetricTile(title: "CPU 温度", value: Formatters.celsius(sample?.cpuTemperatureC), detail: sensorDetail(count: sample?.cpuTemperatureSensorCount), systemImage: "thermometer.high", tint: .red)
            MetricTile(title: "GPU 温度", value: Formatters.celsius(sample?.gpuTemperatureC), detail: sensorDetail(count: sample?.gpuTemperatureSensorCount), systemImage: "thermometer.medium", tint: .pink)
            MetricTile(title: "芯片温度", value: Formatters.celsius(sample?.socTemperatureC), detail: sensorDetail(count: sample?.socTemperatureSensorCount), systemImage: "sensor.tag.radiowaves.forward", tint: .teal)
            MetricTile(title: "热状态", value: sample?.thermalState ?? "等待", detail: sample?.thermalPressure ?? "ProcessInfo", systemImage: "thermometer.sun.fill", tint: (sample?.thermalState ?? "Unknown").thermalTint)

            MetricTile(title: "左风扇", value: Formatters.rpm(displayFanRPM(sample, index: 0)), detail: fanPositionDetail(sample, index: 0), systemImage: "fan", tint: .cyan)
            MetricTile(title: "右风扇", value: Formatters.rpm(displayFanRPM(sample, index: 1)), detail: fanPositionDetail(sample, index: 1), systemImage: "fan", tint: .cyan)
            MetricTile(title: "硬盘温度", value: Formatters.celsius(sample?.diskTemperatureC), detail: sample?.diskTemperatureSourceDetail ?? "等待 SMART", systemImage: "internaldrive", tint: .mint)
            MetricTile(title: "存储芯片热点", value: Formatters.celsius(sample?.ssdTemperatureC), detail: "AppleSMC NAND/Storage", systemImage: "memorychip", tint: .mint)

            MetricTile(title: "Wi-Fi 模块", value: Formatters.celsius(sample?.wifiTemperatureC), detail: "无线模块温度", systemImage: "wifi", tint: .blue)
            MetricTile(title: "气流温度", value: Formatters.celsius(sample?.airflowTemperatureC), detail: "Airflow", systemImage: "wind", tint: .cyan)
            MetricTile(title: "掌托/环境", value: Formatters.celsius(sample?.ambientTemperatureC), detail: "Ambient best effort", systemImage: "hand.raised", tint: .purple)
            MetricTile(title: "P 核频率", value: Formatters.ghzFromMHz(sample?.pClusterFrequencyMHz), detail: "powermetrics", systemImage: "speedometer", tint: .green)

            MetricTile(title: "E 核频率", value: Formatters.ghzFromMHz(sample?.eClusterFrequencyMHz), detail: "powermetrics", systemImage: "speedometer", tint: .mint)
            MetricTile(title: "GPU 频率", value: Formatters.ghzFromMHz(sample?.gpuFrequencyMHz), detail: "powermetrics", systemImage: "speedometer", tint: .blue)
            MetricTile(title: "持续功耗", value: Formatters.watts(rolling.sustainedPower60sW), detail: "60 秒滚动平均", systemImage: "waveform.path.ecg", tint: .purple)
            MetricTile(title: "估算能耗", value: Formatters.wh(rolling.estimatedEnergyWh), detail: rolling.energyDetail, systemImage: "battery.100percent.bolt", tint: .mint)
        }
    }

    private func activityDetail(_ percent: Double?) -> String {
        guard percent != nil else { return "等待活跃度" }
        return "活跃度 \(Formatters.percent(percent))"
    }

    private func sensorDetail(count: Int?) -> String {
        if let count, count > 0 { return String(format: L10n.t("%d 个传感器"), count) }
        return "等待传感器"
    }

    private func fanRPM(_ sample: TelemetrySample?, index: Int) -> Double? {
        guard let fanRPMs = sample?.fanRPMs, fanRPMs.indices.contains(index) else { return nil }
        return fanRPMs[index]
    }

    private func displayFanRPM(_ sample: TelemetrySample?, index: Int) -> Double? {
        guard sample != nil else { return nil }
        return fanRPM(sample, index: index) ?? 0
    }

    private func fanPositionDetail(_ sample: TelemetrySample?, index: Int) -> String {
        guard sample != nil else { return "等待 AppleSMC" }
        guard let fanRPMs = sample?.fanRPMs, fanRPMs.indices.contains(index) else { return "关闭 / 0 RPM" }
        if fanRPMs[index] == 0 { return "关闭 / 0 RPM" }
        return index == 0 ? "AppleSMC F0Ac" : "AppleSMC F1Ac"
    }
}

struct HardwareMetricTile: View {
    var row: HardwareInfoRow
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: row.systemImage)
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                Spacer()
            }
            Text(L10n.t(row.value))
                .font(.system(size: 28, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .frame(height: 38, alignment: .bottomLeading)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(L10n.t(row.title))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    InfoHelpButton(title: row.title, message: row.help)
                }
                if let detail = row.detail, !detail.isEmpty {
                    Text(L10n.t(detail))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .truncationMode(.tail)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .labGlassCard(padding: 15, cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }
}

struct HardwareInfoRowView: View {
    var row: HardwareInfoRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(L10n.t(row.title))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                InfoHelpButton(title: row.title, message: row.help)
            }
            Spacer(minLength: 18)
            VStack(alignment: .trailing, spacing: 2) {
                Text(L10n.t(row.value))
                    .font(isMonospaced ? .body.monospaced() : .body)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
                if let detail = row.detail, !detail.isEmpty {
                    Text(L10n.t(detail))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .font(.callout)
        .padding(.vertical, 5)
    }

    private var isMonospaced: Bool {
        row.value.contains(".") || row.value.contains(",") || row.value.contains("/") || row.value.contains("-")
    }
}
