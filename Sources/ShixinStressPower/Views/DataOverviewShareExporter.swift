import AppKit
import ShixinStressPowerCore
import SwiftUI
import UniformTypeIdentifiers

struct DataOverviewShareExportButton: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Button {
            exportShareImage()
        } label: {
            Label("导出分享图", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.bordered)
        .disabled(appState.currentSample == nil)
        .help(L10n.t("将当前数据概览导出为不含设备私密标识的 PNG 分享图"))
    }

    @MainActor
    private func exportShareImage() {
        guard let sample = appState.currentSample else { return }
        let samples = appState.liveSession?.samples ?? appState.liveSamples
        let snapshot = DataOverviewShareSnapshot(
            sample: sample,
            samples: samples,
            session: appState.liveSession,
            hardwareProfile: appState.hardwareProfile
        )

        let panel = NSSavePanel()
        panel.title = L10n.t("导出数据概览分享图")
        panel.nameFieldStringValue = DataOverviewShareExporter.suggestedFilename(capturedAt: sample.capturedAt)
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        do {
            _ = try DataOverviewShareExporter.export(snapshot: snapshot, to: destinationURL)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

enum DataOverviewShareExporter {
    static func suggestedFilename(capturedAt: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "shixin-maccore-overview-\(formatter.string(from: capturedAt)).png"
    }

    @MainActor
    static func export(snapshot: DataOverviewShareSnapshot, to destinationURL: URL) throws -> URL {
        let size = CGSize(width: 1600, height: 1100)
        let content = DataOverviewShareImage(snapshot: snapshot)
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        renderer.scale = 2

        guard let cgImage = renderer.cgImage else {
            throw ShareReportExportError.renderFailed
        }
        let representation = NSBitmapImageRep(cgImage: cgImage)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw ShareReportExportError.pngEncodingFailed
        }
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try data.write(to: destinationURL, options: [.atomic])
        return destinationURL
    }
}

struct DataOverviewShareSnapshot {
    var sample: TelemetrySample
    var hardwareProfile: HardwareProfile
    var sampleCount: Int
    var peakPowerW: Double?
    var sustainedPower60sW: Double?
    var estimatedEnergyWh: Double?

    init(
        sample: TelemetrySample,
        samples: [TelemetrySample],
        session: LiveSession?,
        hardwareProfile: HardwareProfile
    ) {
        let rolling = RollingTelemetrySummary(samples: samples, session: session)
        self.sample = sample
        self.hardwareProfile = hardwareProfile
        sampleCount = samples.count
        peakPowerW = rolling.peakPowerW
        sustainedPower60sW = rolling.sustainedPower60sW
        estimatedEnergyWh = rolling.estimatedEnergyWh
    }

    func hardwareValue(_ title: String) -> String? {
        if let value = hardwareProfile.headlineRows.first(where: { $0.title == title })?.value {
            return value
        }
        for section in hardwareProfile.sections {
            if let value = section.rows.first(where: { $0.title == title })?.value {
                return value
            }
        }
        return nil
    }
}

private struct DataOverviewShareImage: View {
    var snapshot: DataOverviewShareSnapshot

    private let accentBlue = Color(red: 0.16, green: 0.58, blue: 1.0)
    private let accentGreen = Color(red: 0.24, green: 0.82, blue: 0.48)
    private let accentIndigo = Color(red: 0.48, green: 0.48, blue: 0.98)
    private let accentRed = Color(red: 1.0, green: 0.31, blue: 0.36)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.018, green: 0.025, blue: 0.036),
                    Color(red: 0.033, green: 0.046, blue: 0.064),
                    Color(red: 0.013, green: 0.018, blue: 0.028)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 22) {
                header
                primaryMetrics
                detailPanels
                provenancePanel
                footer
            }
            .padding(52)
        }
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 30) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("SHIXIN LAB · 「芯脉」 MacCore Monitor")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.80))
                    Text("Apple Silicon Stress & Power Monitor")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.white.opacity(0.52))
                }
                Text(L10n.t("数据概览"))
                    .font(.system(size: 56, weight: .semibold))
                Text("\(modelText) · \(chipText)")
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 8) {
                Label(L10n.t("实时硬件快照"), systemImage: "waveform.path.ecg")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accentBlue)
                Text(Formatters.shortDate(snapshot.sample.capturedAt))
                    .font(.system(size: 19, weight: .medium).monospacedDigit())
                Text(String(format: L10n.t("最近窗口 · %d 个样本"), snapshot.sampleCount))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.52))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(accentBlue.opacity(0.28), lineWidth: 1)
            }
        }
    }

    private var primaryMetrics: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4),
            spacing: 14
        ) {
            OverviewShareMetric(
                title: "总/包功耗",
                value: Formatters.watts(snapshot.sample.totalDisplayedPowerW),
                detail: "当前系统估算",
                systemImage: "bolt.fill",
                tint: accentBlue
            )
            OverviewShareMetric(
                title: "CPU 功耗",
                value: Formatters.watts(snapshot.sample.cpuPowerW),
                detail: activityText(snapshot.sample.cpuActivePercent),
                systemImage: "cpu",
                tint: accentGreen
            )
            OverviewShareMetric(
                title: "GPU 功耗",
                value: Formatters.watts(snapshot.sample.gpuPowerW),
                detail: activityText(snapshot.sample.gpuActivePercent),
                systemImage: "rectangle.3.group",
                tint: accentIndigo
            )
            OverviewShareMetric(
                title: "热状态",
                value: L10n.t(snapshot.sample.thermalState),
                detail: snapshot.sample.thermalPressure ?? "ProcessInfo thermalState",
                systemImage: "thermometer.medium",
                tint: snapshot.sample.thermalState.thermalTint
            )
        }
    }

    private var detailPanels: some View {
        HStack(alignment: .top, spacing: 18) {
            OverviewSharePanel(title: "温度与散热", systemImage: "thermometer.variable", tint: accentRed) {
                OverviewShareRow(title: "CPU 温度", value: Formatters.celsius(snapshot.sample.cpuTemperatureC))
                OverviewShareRow(title: "GPU 温度", value: Formatters.celsius(snapshot.sample.gpuTemperatureC))
                OverviewShareRow(title: "芯片温度", value: Formatters.celsius(snapshot.sample.socTemperatureC))
                OverviewShareRow(title: "硬盘温度", value: Formatters.celsius(snapshot.sample.diskTemperatureC))
                OverviewShareRow(title: "存储芯片热点", value: Formatters.celsius(snapshot.sample.ssdTemperatureC))
                OverviewShareRow(title: "风扇转速", value: fanSummary)
            }
            OverviewSharePanel(title: "性能与能耗", systemImage: "gauge.with.dots.needle.67percent", tint: accentBlue) {
                OverviewShareRow(title: "P 核频率", value: Formatters.mhz(snapshot.sample.pClusterFrequencyMHz))
                OverviewShareRow(title: "E 核频率", value: Formatters.mhz(snapshot.sample.eClusterFrequencyMHz))
                OverviewShareRow(title: "GPU 频率", value: Formatters.mhz(snapshot.sample.gpuFrequencyMHz))
                OverviewShareRow(title: "峰值功耗", value: Formatters.watts(snapshot.peakPowerW))
                OverviewShareRow(title: "持续功耗", value: Formatters.watts(snapshot.sustainedPower60sW))
                OverviewShareRow(title: "估算能耗", value: Formatters.wh(snapshot.estimatedEnergyWh))
            }
        }
    }

    private var provenancePanel: some View {
        HStack(spacing: 22) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 31, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accentGreen)
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.t("本机只读快照"))
                    .font(.system(size: 19, weight: .semibold))
                Text(L10n.t("不包含序列号、UDID 或平台 UUID；图片由当前实时采样生成，数据不上传。"))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 24)
            VStack(alignment: .trailing, spacing: 5) {
                Text(L10n.t("采样来源"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
                Text(localizedSourceDetail)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
            }
            .frame(maxWidth: 650, alignment: .trailing)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 17)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.09), lineWidth: 1)
        }
    }

    private var footer: some View {
        HStack {
            Text("芯脉 · MacCore Monitor · Stress & Power")
            Spacer()
            Text(L10n.t("功耗与频率为系统估算值；本图用于趋势观察，不等同于实验室认证。"))
        }
        .font(.system(size: 16, weight: .regular))
        .foregroundStyle(.white.opacity(0.48))
    }

    private var modelText: String {
        snapshot.hardwareValue("型号名称") ?? "Mac"
    }

    private var chipText: String {
        snapshot.hardwareValue("SoC") ?? "Apple Silicon"
    }

    private var fanSummary: String {
        guard let fanRPMs = snapshot.sample.fanRPMs, !fanRPMs.isEmpty else {
            return Formatters.rpm(snapshot.sample.primaryFanRPM)
        }
        if fanRPMs.count == 1 {
            return Formatters.rpm(fanRPMs[0])
        }
        return fanRPMs.prefix(2).map(Formatters.rpm).joined(separator: " · ")
    }

    private var localizedSourceDetail: String {
        var text = snapshot.sample.sourceDetail
        text = text.replacingOccurrences(of: "LaunchDaemon helper ", with: "Helper ")
        text = text.replacingOccurrences(of: "-helper", with: "")
        text = text.replacingOccurrences(of: " / ", with: " · ")
        return L10n.t(text)
    }

    private func activityText(_ percent: Double?) -> String {
        guard percent != nil else { return L10n.t("等待活跃度") }
        return "\(L10n.t("活跃度")) \(Formatters.percent(percent))"
    }
}

private struct OverviewShareMetric: View {
    var title: String
    var value: String
    var detail: String
    var systemImage: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                Spacer()
                Text(L10n.t(title))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.52))
            }
            Text(L10n.t(value))
                .font(.system(size: 35, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            Text(L10n.t(detail))
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.47))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
        .background(.white.opacity(0.058), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.28), lineWidth: 1)
        }
    }
}

private struct OverviewSharePanel<Content: View>: View {
    var title: String
    var systemImage: String
    var tint: Color
    private let content: Content

    init(
        title: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L10n.t(title), systemImage: systemImage)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(tint)
            Rectangle()
                .fill(.white.opacity(0.09))
                .frame(height: 1)
            VStack(alignment: .leading, spacing: 13) {
                content
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
        .background(.white.opacity(0.052), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }
}

private struct OverviewShareRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Text(L10n.t(title))
                .foregroundStyle(.white.opacity(0.52))
            Spacer()
            Text(L10n.t(value))
                .fontWeight(.semibold)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .font(.system(size: 17, weight: .regular))
    }
}
