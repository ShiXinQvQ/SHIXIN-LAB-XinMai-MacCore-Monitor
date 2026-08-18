import AppKit
import ShixinStressPowerCore
import SwiftUI

enum ShareReportExporter {
    static func suggestedFilename(for session: StressSessionSummary) -> String {
        "shixin-mac-stress-report-\(filenameTimestamp(session.startedAt))-\(filenameComponent(session.configuration.mode.rawValue)).png"
    }

    @MainActor
    static func export(
        session: StressSessionSummary,
        hardwareProfile: HardwareProfile,
        to destinationURL: URL
    ) throws -> URL {
        let imageView = ShareReportImageView(session: session, hardwareProfile: hardwareProfile)
            .frame(width: 1600, height: 1000)
        let renderer = ImageRenderer(content: imageView)
        renderer.proposedSize = ProposedViewSize(width: 1600, height: 1000)
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

    private static func filenameTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    private static func filenameComponent(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

enum ShareReportExportError: LocalizedError {
    case renderFailed
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return L10n.t("分享图渲染失败。")
        case .pngEncodingFailed:
            return L10n.t("分享图 PNG 编码失败。")
        }
    }
}

private struct ShareReportImageView: View {
    var session: StressSessionSummary
    var hardwareProfile: HardwareProfile

    private let contentWidth: CGFloat = 1496
    private let modePanelWidth: CGFloat = 286

    private var report: PerformanceThermalReport? {
        session.performanceReport
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.018, green: 0.025, blue: 0.034),
                    Color(red: 0.035, green: 0.047, blue: 0.065),
                    Color(red: 0.012, green: 0.017, blue: 0.026)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 22) {
                header
                HStack(alignment: .top, spacing: 22) {
                    metricGrid
                        .frame(width: 890)
                    sidePanel
                }
                curvePanel
                footer
            }
            .padding(52)
        }
        .foregroundStyle(.white)
    }

    private var header: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("SHIXIN LAB · 「芯脉」 MacCore Monitor")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                    Text("Apple Silicon Stress & Power Monitor")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                Text(L10n.t("性能热力报告"))
                    .font(.system(size: 58, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("\(modelText) · \(chipText) · \(configurationSummary)")
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, modePanelWidth + 36)

            ShareModePanel(
                mode: session.configuration.mode.title,
                timeRange: "\(Formatters.shortDate(session.startedAt)) - \(Formatters.shortDate(session.endedAt))",
                tint: modeTint
            )
            .frame(width: modePanelWidth)
        }
        .frame(width: contentWidth, alignment: .topLeading)
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            ShareMetricTile(title: "持续时间", value: Formatters.seconds(session.durationSeconds), tint: .cyan)
            ShareMetricTile(title: "峰值功耗", value: Formatters.watts(session.peakPowerW), tint: .yellow)
            ShareMetricTile(title: "60 秒持续", value: Formatters.watts(session.validatedSustainedPower60sW), tint: .purple)
            ShareMetricTile(title: "5 分钟持续", value: Formatters.watts(session.validatedSustainedPower300sW), tint: .blue)
            ShareMetricTile(title: "最高温度", value: Formatters.celsius(report?.peakCompositeTemperatureC ?? compositeTemperaturePeak), tint: .red)
            ShareMetricTile(title: "平均温度", value: Formatters.celsius(report?.averageCompositeTemperatureC), tint: .pink)
            ShareMetricTile(title: "最差热状态", value: session.worstThermalState, tint: session.worstThermalState.thermalTint)
            ShareMetricTile(title: "估算能耗", value: Formatters.wh(session.estimatedEnergyWh), tint: .mint)
            ShareMetricTile(title: "峰值风扇转速", value: Formatters.rpmCompact(session.peakFanRPM), tint: .teal)
        }
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 17) {
            VStack(alignment: .leading, spacing: 9) {
                Text(L10n.t("持续性能释放稳定程度"))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                HStack(alignment: .center, spacing: 11) {
                    Image(systemName: report?.stability.level.symbolName ?? "questionmark.circle")
                        .font(.system(size: 31, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(stabilityTint)
                    Text(L10n.t(report?.stability.level.rawValue ?? "采样不足，无法判断"))
                        .font(.system(size: 27, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.66)
                }
                Text(L10n.t(report?.throttlingHint ?? "采样不足，暂不判断"))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 10) {
                ShareKeyValue(title: "SoC", value: chipText)
                ShareKeyValue(title: "CPU 内核", value: hardwareValue("CPU 内核") ?? "未知")
                ShareKeyValue(title: "GPU 内核", value: hardwareValue("GPU 内核") ?? "未知")
                ShareKeyValue(title: "系统内存", value: hardwareValue("系统内存") ?? "未知")
                ShareKeyValue(title: "系统版本", value: hardwareValue("系统版本") ?? "未知")
                ShareKeyValue(title: "内核版本", value: hardwareValue("内核版本") ?? "未知")
                ShareKeyValue(title: "有效采样率", value: Formatters.percent(report?.samplingCompletenessPercent))
                ShareKeyValue(title: "有效样本", value: validSampleSummary)
            }
        }
        .padding(.top, 22)
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, minHeight: 406, alignment: .topLeading)
        .background(.white.opacity(0.058), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(stabilityTint.opacity(0.42), lineWidth: 1)
        }
        .frame(maxWidth: .infinity)
    }

    private var curvePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.t("功耗与温度趋势"))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                HStack(spacing: 12) {
                    ShareLegendItem(title: "总功耗", color: .yellow)
                    ShareLegendItem(title: "最高温度", color: .red)
                    if let latestPowerText {
                        ShareValueBadge(title: "最终功耗", value: latestPowerText, color: .yellow)
                    }
                    if let latestTemperatureText {
                        ShareValueBadge(title: "最终温度", value: latestTemperatureText, color: .red)
                    }
                }
            }
            ShareCurveThumbnail(
                samples: session.samples,
                mode: session.configuration.mode,
                knownGaps: session.curveArchiveMetadata?.samplingGaps
            )
                .frame(height: 214)
        }
        .padding(22)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var footer: some View {
        HStack {
            Text("芯脉 · MacCore Monitor")
            Spacer()
            Text(L10n.t("powermetrics 为系统估算值，趋势判断不等于实验室认证。"))
        }
        .font(.system(size: 17, weight: .regular))
        .foregroundStyle(.white.opacity(0.5))
    }

    private var stabilityTint: Color {
        switch report?.stability.level {
        case .stable: .green
        case .slightRegression: .orange
        case .possibleThermalLimit: .red
        case .insufficientData, nil: .gray
        }
    }

    private var modelText: String {
        hardwareValue("型号名称") ?? "Mac"
    }

    private var chipText: String {
        hardwareValue("SoC") ?? "Apple Silicon"
    }

    private var modeTint: Color {
        switch session.configuration.mode {
        case .cpu:
            Color(red: 0.42, green: 0.82, blue: 1.0)
        case .gpu:
            Color(red: 0.62, green: 0.56, blue: 1.0)
        case .combined:
            Color(red: 0.3, green: 0.95, blue: 0.75)
        }
    }

    private var configurationSummary: String {
        [
            hardwareValue("CPU 内核"),
            hardwareValue("GPU 内核"),
            hardwareValue("系统内存")
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private var compositeTemperaturePeak: Double? {
        [session.peakCPUTemperatureC, session.peakGPUTemperatureC, session.peakSoCTemperatureC].compactMap { $0 }.max()
    }

    private var validSampleSummary: String {
        let sampleCount = report?.sampleCount ?? session.sampleCount
        if let validSampleCount = report?.validSampleCount {
            return "\(validSampleCount) / \(sampleCount)"
        }
        let degradedCount = report?.degradedSampleCount ?? session.degradedSampleCount
        return "\(max(0, sampleCount - degradedCount)) / \(sampleCount)"
    }

    private var latestPowerText: String? {
        session.samples.reversed().compactMap(\.totalDisplayedPowerW).first.map(Formatters.watts)
    }

    private var latestTemperatureText: String? {
        session.samples.reversed()
            .compactMap { sample in
                [sample.cpuTemperatureC, sample.gpuTemperatureC, sample.socTemperatureC].compactMap { $0 }.max()
            }
            .first
            .map { String(format: "%.1f °C", $0) }
    }

    private func hardwareValue(_ title: String) -> String? {
        if let snapshot = session.environmentSnapshot {
            let snapshotValue: String?
            switch title {
            case "型号名称": snapshotValue = snapshot.modelName
            case "型号标识符": snapshotValue = snapshot.modelIdentifier
            case "SoC": snapshotValue = snapshot.soc
            case "CPU 内核": snapshotValue = snapshot.cpuCores
            case "GPU 内核": snapshotValue = snapshot.gpuCores
            case "系统内存": snapshotValue = snapshot.systemMemory
            case "系统版本": snapshotValue = snapshot.systemVersion
            case "内核版本": snapshotValue = snapshot.kernelVersion
            default: snapshotValue = nil
            }
            if let snapshotValue, !snapshotValue.isEmpty {
                return snapshotValue
            }
        }
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

private struct ShareModePanel: View {
    var mode: String
    var timeRange: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(tint)
                    .frame(width: 4, height: 48)
                    .clipShape(Capsule())
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("测试模式"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.56))
                    Text(L10n.t(mode))
                        .font(.system(size: 28, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            Text(timeRange)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.062), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct ShareMetricTile: View {
    var title: String
    var value: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t(title))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.56))
                .lineLimit(1)
                .minimumScaleFactor(0.74)
            Text(L10n.t(value))
                .font(.system(size: 30, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            Rectangle()
                .fill(tint.opacity(0.75))
                .frame(width: 42, height: 3)
                .clipShape(Capsule())
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        }
    }
}

private struct ShareKeyValue: View {
    var title: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(L10n.t(title))
                .foregroundStyle(.white.opacity(0.54))
            Spacer(minLength: 16)
            Text(L10n.t(value))
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .font(.system(size: 15, weight: .regular))
    }
}

private struct ShareValueBadge: View {
    var title: String
    var value: String
    var color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(L10n.t(title))
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.86))
        }
        .font(.system(size: 13, weight: .regular))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.14), in: Capsule())
        .overlay {
            Capsule()
                .stroke(color.opacity(0.30), lineWidth: 1)
        }
    }
}

private struct ShareLegendItem: View {
    var title: String
    var color: Color

    var body: some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(color)
                .frame(width: 18, height: 4)
            Text(L10n.t(title))
        }
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(.white.opacity(0.72))
    }
}

private struct ShareCurveThumbnail: View {
    var samples: [TelemetrySample]
    var mode: StressMode
    var knownGaps: [TelemetrySamplingGap]?

    private struct AxisDateLabel: Identifiable {
        var id: Int
        var date: Date
    }

    private var chartSamples: [TelemetrySample] {
        TelemetryCurveCompressor.archive(samples: samples, maxSamples: 320, mode: mode).samples
    }

    private var powerValues: [Double] {
        chartSamples.compactMap(\.totalDisplayedPowerW)
    }

    private var temperatureValues: [Double] {
        chartSamples.compactMap { sample in
            [sample.cpuTemperatureC, sample.gpuTemperatureC, sample.socTemperatureC].compactMap { $0 }.max()
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let plot = plotRect(in: size)
            let powerBounds = axisBounds(values: powerValues, includeZero: true, padding: 2)
            let temperatureBounds = axisBounds(values: temperatureValues, includeZero: false, padding: 3)
            let powerTicks = axisTicks(min: powerBounds.min, max: powerBounds.max)
            let temperatureTicks = axisTicks(min: temperatureBounds.min, max: temperatureBounds.max)

            ZStack {
                Canvas { context, canvasSize in
                    let plot = plotRect(in: canvasSize)
                    let powerBounds = axisBounds(values: powerValues, includeZero: true, padding: 2)
                    let temperatureBounds = axisBounds(values: temperatureValues, includeZero: false, padding: 3)
                    let powerTicks = axisTicks(min: powerBounds.min, max: powerBounds.max)
                    let xTickDates = xAxisTickDates

                    var grid = Path()
                    for value in powerTicks {
                        let y = yPosition(value: value, bounds: powerBounds, plot: plot)
                        grid.move(to: CGPoint(x: plot.minX, y: y))
                        grid.addLine(to: CGPoint(x: plot.maxX, y: y))
                    }
                    for date in xTickDates {
                        let x = xPosition(date: date, plot: plot)
                        grid.move(to: CGPoint(x: x, y: plot.minY))
                        grid.addLine(to: CGPoint(x: x, y: plot.maxY))
                    }
                    context.stroke(grid, with: .color(.white.opacity(0.09)), lineWidth: 1)

                    var axis = Path()
                    axis.move(to: CGPoint(x: plot.minX, y: plot.minY))
                    axis.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
                    axis.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
                    axis.move(to: CGPoint(x: plot.maxX, y: plot.minY))
                    axis.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
                    context.stroke(axis, with: .color(.white.opacity(0.2)), lineWidth: 1.2)

                    let powerPath = seriesPath(
                        value: { $0.totalDisplayedPowerW },
                        bounds: powerBounds,
                        plot: plot
                    )
                    context.stroke(powerPath, with: .color(.yellow), style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round))

                    let temperaturePath = seriesPath(
                        value: { sample in
                            [sample.cpuTemperatureC, sample.gpuTemperatureC, sample.socTemperatureC].compactMap { $0 }.max()
                        },
                        bounds: temperatureBounds,
                        plot: plot
                    )
                    context.stroke(temperaturePath, with: .color(.red.opacity(0.9)), style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round))
                }

                ForEach(Array(powerTicks.enumerated()), id: \.offset) { _, value in
                    Text(String(format: "%.0f W", value))
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.52))
                        .position(x: 34, y: yPosition(value: value, bounds: powerBounds, plot: plot))
                }

                ForEach(Array(temperatureTicks.enumerated()), id: \.offset) { _, value in
                    Text(String(format: "%.0f°", value))
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.52))
                        .position(x: size.width - 31, y: yPosition(value: value, bounds: temperatureBounds, plot: plot))
                }

                ForEach(xAxisLabels) { item in
                    Text(timeLabel(item.date))
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.5))
                        .position(
                            x: xPosition(date: item.date, plot: plot),
                            y: size.height - 16
                        )
                }

                if chartSamples.isEmpty {
                    Text(L10n.t("等待样本"))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private var xAxisLabels: [AxisDateLabel] {
        timelineDates(fractions: [0, 0.5, 1])
            .enumerated()
            .map { AxisDateLabel(id: $0.offset, date: $0.element) }
    }

    private var xAxisTickDates: [Date] {
        timelineDates(fractions: [0, 0.25, 0.5, 0.75, 1])
    }

    private func timelineDates(fractions: [Double]) -> [Date] {
        guard let first = chartSamples.first?.capturedAt,
              let last = chartSamples.last?.capturedAt else {
            return []
        }
        let duration = last.timeIntervalSince(first)
        guard duration > 0 else { return [first] }
        return fractions.map { first.addingTimeInterval(duration * $0) }
    }

    private func plotRect(in size: CGSize) -> CGRect {
        CGRect(
            x: 72,
            y: 16,
            width: max(1, size.width - 144),
            height: max(1, size.height - 58)
        )
    }

    private func axisBounds(values: [Double], includeZero: Bool, padding: Double) -> (min: Double, max: Double) {
        guard let rawMin = values.min(), let rawMax = values.max(), rawMin.isFinite, rawMax.isFinite else {
            return includeZero ? (0, 100) : (20, 100)
        }
        let lowerSeed = includeZero ? min(0, rawMin) : rawMin - padding
        let upperSeed = rawMax + padding
        let lower = includeZero ? 0 : floor(lowerSeed / 5) * 5
        var upper = ceil(upperSeed / 5) * 5
        if upper <= lower {
            upper = lower + 10
        }
        return (lower, upper)
    }

    private func axisTicks(min: Double, max: Double) -> [Double] {
        let step = (max - min) / 4
        return (0...4).map { min + Double($0) * step }
    }

    private func xPosition(date: Date, plot: CGRect) -> CGFloat {
        guard let first = chartSamples.first?.capturedAt,
              let last = chartSamples.last?.capturedAt,
              last > first else {
            return plot.midX
        }
        let rawRatio = date.timeIntervalSince(first) / last.timeIntervalSince(first)
        let ratio = CGFloat(max(0, min(1, rawRatio)))
        return plot.minX + ratio * plot.width
    }

    private func yPosition(value: Double, bounds: (min: Double, max: Double), plot: CGRect) -> CGFloat {
        let range = max(0.0001, bounds.max - bounds.min)
        let ratio = CGFloat((value - bounds.min) / range)
        return plot.maxY - ratio * plot.height
    }

    private func seriesPath(
        value: (TelemetrySample) -> Double?,
        bounds: (min: Double, max: Double),
        plot: CGRect
    ) -> Path {
        var path = Path()
        var isDrawing = false
        var previousDate: Date?
        let inferredGapThreshold = knownGaps == nil
            ? TelemetryCurveCompressor.timingSummary(samples: chartSamples).trustedGapThresholdSeconds
            : nil
        for sample in chartSamples {
            guard let rawValue = value(sample), rawValue.isFinite else {
                isDrawing = false
                previousDate = nil
                continue
            }
            if let previousDate {
                let crossesGap: Bool
                if let knownGaps {
                    crossesGap = knownGaps.contains {
                        $0.startedAt >= previousDate && $0.endedAt <= sample.capturedAt
                    }
                } else {
                    crossesGap = sample.capturedAt.timeIntervalSince(previousDate) > (inferredGapThreshold ?? 2)
                }
                if crossesGap {
                    isDrawing = false
                }
            }
            let point = CGPoint(
                x: xPosition(date: sample.capturedAt, plot: plot),
                y: yPosition(value: rawValue, bounds: bounds, plot: plot)
            )
            if isDrawing {
                path.addLine(to: point)
            } else {
                path.move(to: point)
                isDrawing = true
            }
            previousDate = sample.capturedAt
        }
        return path
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
