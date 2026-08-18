import AppKit
import Charts
import ShixinStressPowerCore
import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var compareMode = false
    @State private var compareAID: StressSessionSummary.ID?
    @State private var compareBID: StressSessionSummary.ID?

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width < 920 {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        historyList
                        historyDetail
                    }
                    .padding(22)
                }
            } else {
                HStack(spacing: 0) {
                    historyList
                        .frame(width: min(340, max(300, proxy.size.width * 0.26)))
                        .padding(18)
                        .background(.ultraThinMaterial)
                    Divider().opacity(0.25)
                    ScrollView {
                        historyDetail
                            .padding(22)
                    }
                }
            }
        }
        .onAppear(perform: ensureCompareDefaults)
        .onChange(of: appState.sessions.map(\.id)) { _, _ in
            ensureCompareDefaults()
        }
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("历史记录")
                        .font(.title2.weight(.semibold))
                    InfoHelpButton(title: "历史记录", message: "这里保存本机完成过的压力测试 Session。列表会显示模式、持续时间、峰值功耗和停止原因，方便对比不同测试。")
                }
                Spacer()
                Button {
                    compareMode.toggle()
                    ensureCompareDefaults()
                } label: {
                    Label(compareMode ? "退出对比" : "对比模式", systemImage: compareMode ? "xmark.circle" : "rectangle.split.2x1")
                }
                .disabled(appState.sessions.count < 2)
                Button {
                    appState.loadSessions()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            }

            if appState.sessions.isEmpty {
                ContentUnavailableView("还没有烤机历史", systemImage: "clock.badge.questionmark", description: Text("完成一次压力测试后，这里会保存 session 摘要与曲线。"))
                    .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                if compareMode {
                    CompareSelectionCard(sessions: appState.sessions, compareAID: $compareAID, compareBID: $compareBID)
                }
                List(appState.sessions, selection: $appState.selectedSessionID) { session in
                    SessionRow(session: session)
                        .tag(session.id)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 300)
            }
        }
    }

    @ViewBuilder
    private var historyDetail: some View {
        if compareMode {
            comparisonDetail
        } else if let session = appState.selectedSession {
            SessionDetail(session: session)
        } else {
            ContentUnavailableView("选择一次历史", systemImage: "doc.text.magnifyingglass", description: Text("完成或选择压力测试历史后可查看详情。"))
                .frame(maxWidth: .infinity, minHeight: 320)
        }
    }

    @ViewBuilder
    private var comparisonDetail: some View {
        if appState.sessions.count < 2 {
            ContentUnavailableView("至少需要两次历史记录才能对比。", systemImage: "rectangle.split.2x1", description: Text("完成更多压力测试后即可比较 A/B 表现。"))
                .frame(maxWidth: .infinity, minHeight: 320)
        } else if let sessionA = session(for: compareAID),
                  let sessionB = session(for: compareBID),
                  sessionA.id != sessionB.id {
            SessionCompareView(sessionA: sessionA, sessionB: sessionB)
        } else {
            ContentUnavailableView("选择两次 Session", systemImage: "arrow.left.arrow.right", description: Text("请选择 A/B 两次不同的压力测试记录。"))
                .frame(maxWidth: .infinity, minHeight: 320)
        }
    }

    private func session(for id: StressSessionSummary.ID?) -> StressSessionSummary? {
        guard let id else { return nil }
        return appState.sessions.first { $0.id == id }
    }

    private func ensureCompareDefaults() {
        guard !appState.sessions.isEmpty else {
            compareAID = nil
            compareBID = nil
            return
        }
        let ids = appState.sessions.map(\.id)
        if compareAID == nil || compareAID.map({ !ids.contains($0) }) == true {
            compareAID = ids.first
        }
        if compareBID == nil || compareBID == compareAID || compareBID.map({ !ids.contains($0) }) == true {
            compareBID = ids.first { $0 != compareAID } ?? ids.first
        }
    }
}

struct SessionRow: View {
    var session: StressSessionSummary

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: session.configuration.mode.systemImage)
                .foregroundStyle(session.worstThermalState.thermalTint)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(Formatters.shortDate(session.startedAt))
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text("\(L10n.t(session.configuration.mode.title)) · \(Formatters.seconds(session.durationSeconds))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(L10n.t("峰值")) \(Formatters.watts(session.peakPowerW)) · \(L10n.t(session.stopReason.rawValue))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}

struct CompareSelectionCard: View {
    var sessions: [StressSessionSummary]
    @Binding var compareAID: StressSessionSummary.ID?
    @Binding var compareBID: StressSessionSummary.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "选择两次 Session",
                systemImage: "arrow.left.arrow.right",
                help: "对比模式会并排显示 A/B 两次历史测试的核心指标，并用 B - A 显示差值。不同模式或采样降级时，结果应结合完整 CSV 复核。"
            )
            Picker("选择 A", selection: $compareAID) {
                ForEach(sessions) { session in
                    Text(selectionTitle(session)).tag(Optional(session.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            Picker("选择 B", selection: $compareBID) {
                ForEach(sessions) { session in
                    Text(selectionTitle(session)).tag(Optional(session.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
        .labGlassCard(padding: 14, cornerRadius: 16)
    }

    private func selectionTitle(_ session: StressSessionSummary) -> String {
        "\(Formatters.shortDate(session.startedAt)) · \(L10n.t(session.configuration.mode.title)) · \(Formatters.seconds(session.durationSeconds))"
    }
}

struct SessionCompareView: View {
    var sessionA: StressSessionSummary
    var sessionB: StressSessionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("对比摘要")
                    .font(.title2.weight(.semibold))
                InfoHelpButton(title: "对比摘要", message: "这里以 A/B 两次历史 Session 对比核心功耗、温度、风扇、热状态、有效采样率和稳定性判断。差值按 B - A 计算。")
                Spacer()
                StatusPill(text: "Δ B-A", systemImage: "plus.forwardslash.minus", tint: .cyan)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    CompareSessionHeaderCard(label: "Session A", session: sessionA, tint: .blue)
                    CompareSessionHeaderCard(label: "Session B", session: sessionB, tint: .orange)
                }
                VStack(alignment: .leading, spacing: 14) {
                    CompareSessionHeaderCard(label: "Session A", session: sessionA, tint: .blue)
                    CompareSessionHeaderCard(label: "Session B", session: sessionB, tint: .orange)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                CompareMetricCard.text(title: "模式", a: sessionA.configuration.mode.title, b: sessionB.configuration.mode.title, systemImage: "flame.fill", tint: .orange)
                CompareMetricCard.numeric(title: "持续时间", a: sessionA.durationSeconds, b: sessionB.durationSeconds, unit: "s", decimals: 0, display: { $0.map(Formatters.seconds) ?? "不可用" }, systemImage: "timer", tint: .cyan)
                CompareMetricCard.numeric(title: "峰值功耗", a: sessionA.peakPowerW, b: sessionB.peakPowerW, unit: "W", decimals: 1, display: Formatters.watts, systemImage: "bolt.fill", tint: .yellow)
                CompareMetricCard.numeric(title: "60 秒持续", a: sessionA.validatedSustainedPower60sW, b: sessionB.validatedSustainedPower60sW, unit: "W", decimals: 1, display: Formatters.watts, systemImage: "waveform.path.ecg", tint: .purple)
                CompareMetricCard.numeric(title: "5 分钟持续", a: sessionA.validatedSustainedPower300sW, b: sessionB.validatedSustainedPower300sW, unit: "W", decimals: 1, display: Formatters.watts, systemImage: "gauge.with.dots.needle.67percent", tint: .blue)
                CompareMetricCard.numeric(title: "估算能耗", a: sessionA.estimatedEnergyWh, b: sessionB.estimatedEnergyWh, unit: "Wh", decimals: 2, display: Formatters.wh, systemImage: "battery.100percent.bolt", tint: .mint)
                CompareMetricCard.numeric(title: "CPU 峰值温度", a: sessionA.peakCPUTemperatureC, b: sessionB.peakCPUTemperatureC, unit: "°C", decimals: 1, display: Formatters.celsius, systemImage: "thermometer.high", tint: .red)
                CompareMetricCard.numeric(title: "GPU 峰值温度", a: sessionA.peakGPUTemperatureC, b: sessionB.peakGPUTemperatureC, unit: "°C", decimals: 1, display: Formatters.celsius, systemImage: "thermometer.medium", tint: .pink)
                CompareMetricCard.numeric(title: "芯片峰值温度", a: sessionA.peakSoCTemperatureC, b: sessionB.peakSoCTemperatureC, unit: "°C", decimals: 1, display: Formatters.celsius, systemImage: "sensor.tag.radiowaves.forward", tint: .teal)
                CompareMetricCard.numeric(title: "峰值风扇转速", a: sessionA.peakFanRPM, b: sessionB.peakFanRPM, unit: "rpm", decimals: 0, display: Formatters.rpmCompact, systemImage: "fan", tint: .cyan)
                CompareMetricCard.numeric(title: "最差热状态", a: Double(thermalRank(sessionA.worstThermalState)), b: Double(thermalRank(sessionB.worstThermalState)), unit: "", decimals: 0, display: { _ in sessionA.worstThermalState }, bDisplay: sessionB.worstThermalState, systemImage: "thermometer.sun.fill", tint: sessionB.worstThermalState.thermalTint)
                CompareMetricCard.numeric(title: "有效采样率", a: samplingCompleteness(sessionA), b: samplingCompleteness(sessionB), unit: "%", decimals: 0, display: Formatters.percent, systemImage: "checkmark.seal", tint: .green)
                CompareMetricCard.text(title: "持续性能释放稳定程度", a: stabilityTitle(sessionA), b: stabilityTitle(sessionB), systemImage: "speedometer", tint: stabilityTint(sessionB))
            }
        }
    }

    private func samplingCompleteness(_ session: StressSessionSummary) -> Double? {
        if let percent = session.performanceReport?.samplingCompletenessPercent {
            return percent
        }
        guard session.sampleCount > 0 else { return nil }
        return Double(session.sampleCount - session.degradedSampleCount) / Double(session.sampleCount) * 100
    }

    private func stabilityTitle(_ session: StressSessionSummary) -> String {
        session.performanceReport?.stability.level.rawValue ?? "不可用"
    }

    private func stabilityTint(_ session: StressSessionSummary) -> Color {
        switch session.performanceReport?.stability.level {
        case .stable: .green
        case .slightRegression: .orange
        case .possibleThermalLimit: .red
        case .insufficientData, nil: .gray
        }
    }

    private func thermalRank(_ state: String) -> Int {
        switch state {
        case "Nominal": 0
        case "Fair": 1
        case "Serious": 2
        case "Critical": 3
        default: -1
        }
    }
}

struct CompareSessionHeaderCard: View {
    var label: String
    var session: StressSessionSummary
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatusPill(text: label, systemImage: session.configuration.mode.systemImage, tint: tint)
            Text(Formatters.shortDate(session.startedAt))
                .font(.title3.weight(.semibold))
                .lineLimit(1)
            Text("\(L10n.t(session.configuration.mode.title)) · \(Formatters.seconds(session.durationSeconds)) · \(Formatters.watts(session.peakPowerW))")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(L10n.t(session.stopReason.rawValue))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .labGlassCard(padding: 16, cornerRadius: 16)
    }
}

struct CompareMetricCard: View {
    var title: String
    var aText: String
    var bText: String
    var deltaText: String
    var systemImage: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 22)
                Text(L10n.t(title))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 0)
                InfoHelpButton(title: title, message: help)
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                compareColumn("A", aText)
                compareColumn("B", bText)
            }
            Text(deltaText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .labGlassCard(padding: 14, cornerRadius: 16)
    }

    static func text(title: String, a: String, b: String, systemImage: String, tint: Color) -> CompareMetricCard {
        CompareMetricCard(
            title: title,
            aText: a,
            bText: b,
            deltaText: a == b ? L10n.t("一致") : L10n.t("不同"),
            systemImage: systemImage,
            tint: tint
        )
    }

    static func numeric(
        title: String,
        a: Double?,
        b: Double?,
        unit: String,
        decimals: Int,
        display: (Double?) -> String,
        bDisplay: String? = nil,
        systemImage: String,
        tint: Color
    ) -> CompareMetricCard {
        let delta = deltaText(a: a, b: b, unit: unit, decimals: decimals)
        return CompareMetricCard(
            title: title,
            aText: display(a),
            bText: bDisplay ?? display(b),
            deltaText: delta,
            systemImage: systemImage,
            tint: tint
        )
    }

    private var help: String {
        switch title {
        case "采样完整度":
            return "非降级样本占总样本的比例。完整度越高，功耗、频率和稳定性判断越值得信任。"
        case "持续性能释放稳定程度":
            return "基于前段与后段功耗、P 核/GPU 频率、温度、热状态和降级样本比例的趋势估算，不是实验室绝对判定。"
        default:
            return "对比卡显示 A/B 两次 Session 的同一指标，差值按 B - A 计算。"
        }
    }

    private func compareColumn(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(L10n.t(value))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func deltaText(a: Double?, b: Double?, unit: String, decimals: Int) -> String {
        guard let a, let b, a.isFinite, b.isFinite else {
            return L10n.t("差值不可用")
        }
        let delta = b - a
        let sign = delta >= 0 ? "+" : ""
        let numberFormat = "%@%.\(decimals)f%@"
        let unitSuffix = unit.isEmpty ? "" : " \(unit)"
        let absolute = String(format: numberFormat, sign, delta, unitSuffix)
        guard abs(a) > 0.0001 else { return "B - A \(absolute)" }
        let percent = delta / abs(a) * 100
        let percentSign = percent >= 0 ? "+" : ""
        return String(format: "B - A %@ (%@%.0f%%)", absolute, percentSign, percent)
    }
}

struct SessionDetail: View {
    @EnvironmentObject private var appState: AppState
    var session: StressSessionSummary
    @State private var showDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Session 详情")
                            .font(.title2.weight(.semibold))
                        InfoHelpButton(title: "Session 详情", message: "这里展示所选历史测试的摘要指标、峰值温度、风扇、热状态和当时保存下来的曲线。")
                    }
                    Text("\(Formatters.shortDate(session.startedAt)) - \(Formatters.shortDate(session.endedAt))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive) {
                    showDelete = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }

            ViewThatFits(in: .horizontal) {
                LazyVGrid(columns: threeMetricColumns, spacing: 10) {
                    sessionMetricTiles
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                    sessionMetricTiles
                }
            }

            PerformanceThermalReportCard(session: session)
                .environmentObject(appState)

            SessionSampleArchiveCard(session: session)
                .environmentObject(appState)

            LivePowerChart(samples: session.samples, knownGaps: session.curveArchiveMetadata?.samplingGaps, sampleLimit: nil)
            LiveTemperatureChart(samples: session.samples, knownGaps: session.curveArchiveMetadata?.samplingGaps, sampleLimit: nil)
            LiveFrequencyChart(samples: session.samples, knownGaps: session.curveArchiveMetadata?.samplingGaps, sampleLimit: nil)
            LiveActivityChart(samples: session.samples, knownGaps: session.curveArchiveMetadata?.samplingGaps, sampleLimit: nil)

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Session 日志", systemImage: "doc.text", help: "记录这次测试开始、停止和安全保护等关键事件。没有额外日志不代表异常，只表示没有更多可记录事件。")
                ForEach(session.logMessages, id: \.self) { line in
                    Text(L10n.t(line))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                if session.logMessages.isEmpty {
                    Text("没有额外日志。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .labGlassCard()
        }
        .confirmationDialog("删除这个 Session？", isPresented: $showDelete) {
            Button("删除", role: .destructive) {
                appState.deleteSession(session)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作只删除本机历史记录，不影响系统和硬件。")
        }
    }

    private var threeMetricColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 160), spacing: 10), count: 3)
    }

    @ViewBuilder
    private var sessionMetricTiles: some View {
        MetricTile(title: "模式", value: session.configuration.mode.title, detail: "Stress Mode", systemImage: session.configuration.mode.systemImage, tint: .orange)
        MetricTile(title: "持续时间", value: Formatters.seconds(session.durationSeconds), detail: session.stopReason.rawValue, systemImage: "timer", tint: .cyan)
        MetricTile(title: "峰值功耗", value: Formatters.watts(session.peakPowerW), detail: "Peak Power", systemImage: "bolt.fill", tint: .yellow)
        MetricTile(title: "60 秒持续", value: Formatters.watts(session.validatedSustainedPower60sW), detail: "Rolling Average", systemImage: "waveform.path.ecg", tint: .purple)
        MetricTile(title: "估算能耗", value: Formatters.wh(session.estimatedEnergyWh), detail: "Energy Estimate", systemImage: "battery.100percent.bolt", tint: .mint)
        MetricTile(title: "CPU 峰值温度", value: Formatters.celsius(session.peakCPUTemperatureC), detail: "CPU Peak", systemImage: "thermometer.high", tint: .red)
        MetricTile(title: "GPU 峰值温度", value: Formatters.celsius(session.peakGPUTemperatureC), detail: "GPU Peak", systemImage: "thermometer.medium", tint: .pink)
        MetricTile(title: "芯片峰值温度", value: Formatters.celsius(session.peakSoCTemperatureC), detail: "SoC Peak", systemImage: "sensor.tag.radiowaves.forward", tint: .teal)
        MetricTile(title: "峰值风扇转速", value: Formatters.rpmCompact(session.peakFanRPM), detail: "Fan Peak", systemImage: "fan", tint: .cyan)
        MetricTile(title: "最差热状态", value: session.worstThermalState, detail: "\(session.sampleCount) \(L10n.t("个样本"))", systemImage: "thermometer.sun.fill", tint: session.worstThermalState.thermalTint)
        MetricTile(title: "采样间隔", value: sampleIntervalText, detail: "\(session.sampleCount) \(L10n.t("个样本"))", systemImage: "dot.radiowaves.left.and.right", tint: .green)
        MetricTile(title: "完整 CSV", value: fullCSVStateText, detail: fullCSVSampleDetail, systemImage: "tablecells", tint: .blue)
    }

    private var sampleIntervalText: String {
        if let interval = session.curveArchiveMetadata?.expectedIntervalSeconds,
           interval > 0,
           interval.isFinite {
            return String(format: "%.2f %@", interval, L10n.t("秒"))
        }
        guard session.sampleCount > 1, session.durationSeconds > 0 else {
            return L10n.t("不可用")
        }
        let interval = session.durationSeconds / Double(session.sampleCount - 1)
        return String(format: "%.2f %@", interval, L10n.t("秒"))
    }

    private var fullCSVSampleDetail: String {
        guard let count = session.fullSampleCSVSampleCount else { return "—" }
        return "\(count) \(L10n.t("个样本"))"
    }

    private var fullCSVStateText: String {
        if appState.store.fullSamplesCSVURL(for: session) != nil {
            return L10n.t("已保存")
        }
        if session.fullSampleCSVPath != nil || session.fullSampleCSVRelativePath != nil {
            return L10n.t("文件缺失")
        }
        return L10n.t("旧记录")
    }
}

struct PerformanceThermalReportCard: View {
    @EnvironmentObject private var appState: AppState
    var session: StressSessionSummary
    @State private var shareMessage: String?
    @State private var isExportingShareImage = false

    private var report: PerformanceThermalReport? {
        session.performanceReport
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 14) {
                    titleBlock
                        .frame(maxWidth: .infinity, alignment: .leading)
                    shareButton
                }
                VStack(alignment: .leading, spacing: 12) {
                    titleBlock
                    shareButton
                }
            }

            if let report {
                reportSummary(report)
                LazyVGrid(columns: threeMetricColumns, spacing: 10) {
                    reportMetricTiles(report)
                }
                KeyValueRow(title: "数据来源摘要", value: localizedDataSourceSummary(report.dataSourceSummary), helpTitle: "数据来源摘要", help: "报告记录本次 Session 中 powermetrics、fallback、温度和风扇样本的数量，用来辅助判断报告可信度。")
                StabilityDetailStrip(report: report)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    StatusPill(text: "旧记录未保存性能热力报告", systemImage: "clock.arrow.circlepath", tint: .orange)
                    Text("这条历史来自旧版本，只包含摘要、轻量曲线和可能的完整 CSV。新完成的 Session 会自动保存正式性能热力报告。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let shareMessage {
                Text(shareMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .labGlassCard()
    }

    private func localizedDataSourceSummary(_ summary: String) -> String {
        summary
            .replacingOccurrences(of: "温度", with: L10n.t("温度"))
            .replacingOccurrences(of: "风扇", with: L10n.t("风扇"))
    }

    private var titleBlock: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text("性能热力报告")
                .font(.title3.weight(.semibold))
            InfoHelpButton(title: "性能热力报告", message: "每次压力测试结束后生成的正式报告。它保存峰值、持续功耗、温度、风扇、有效采样率、数据来源和趋势型稳定性判断；CSV 用于复核完整原始样本。")
        }
    }

    private var shareButton: some View {
        Button {
            exportShareImage()
        } label: {
            Label(isExportingShareImage ? "正在导出分享图..." : "导出分享图", systemImage: "photo.on.rectangle.angled")
        }
        .buttonStyle(.borderedProminent)
        .disabled(isExportingShareImage)
    }

    private var threeMetricColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 160), spacing: 10), count: 3)
    }

    @ViewBuilder
    private func reportMetricTiles(_ report: PerformanceThermalReport) -> some View {
        MetricTile(title: "5 分钟持续", value: Formatters.watts(report.validatedSustainedPower300sW), detail: "300 s", systemImage: "gauge.with.dots.needle.67percent", tint: .blue)
        MetricTile(title: "最高温度", value: Formatters.celsius(report.peakCompositeTemperatureC), detail: "CPU / GPU / SoC", systemImage: "thermometer.high", tint: .red)
        MetricTile(title: "平均温度", value: Formatters.celsius(report.averageCompositeTemperatureC), detail: "Session Average", systemImage: "thermometer.medium", tint: .pink)
        MetricTile(title: "有效采样率", value: Formatters.percent(report.samplingCompletenessPercent), detail: "\(validSampleCount(report)) / \(report.sampleCount)", systemImage: "checkmark.seal", tint: .green)
        MetricTile(title: "频率限制证据", value: hasFrequencyLimitEvidence(report) ? "是" : "否", detail: report.throttlingHint, systemImage: "speedometer", tint: hasFrequencyLimitEvidence(report) ? .orange : .green)
        MetricTile(title: "报告样本", value: "\(report.savedCurveSampleCount) / \(csvSampleCount(report))", detail: "Curve / CSV", systemImage: "point.3.connected.trianglepath.dotted", tint: .cyan)
    }

    private func validSampleCount(_ report: PerformanceThermalReport) -> Int {
        report.validSampleCount ?? max(0, report.sampleCount - report.degradedSampleCount)
    }

    private func csvSampleCount(_ report: PerformanceThermalReport) -> String {
        report.fullSampleCSVSampleCount.map(String.init) ?? "—"
    }

    private func hasFrequencyLimitEvidence(_ report: PerformanceThermalReport) -> Bool {
        if report.reportSchemaVersion != nil {
            return report.hasThrottlingHint
        }
        return report.stability.level == .possibleThermalLimit && report.hasThrottlingHint
    }

    private func reportSummary(_ report: PerformanceThermalReport) -> some View {
        HStack(alignment: .top, spacing: 12) {
            StatusPill(text: report.stability.level.rawValue, systemImage: report.stability.level.symbolName, tint: stabilityTint(report.stability.level))
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t(report.throttlingHint))
                    .font(.headline)
                Text(L10n.t(report.stability.explanation))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(stabilityTint(report.stability.level).opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(stabilityTint(report.stability.level).opacity(0.2), lineWidth: 1)
        }
    }

    private func exportShareImage() {
        let panel = NSSavePanel()
        panel.title = L10n.t("导出分享图")
        panel.nameFieldStringValue = ShareReportExporter.suggestedFilename(for: session)
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isExportingShareImage = true
        shareMessage = L10n.t("正在导出分享图...")
        Task { @MainActor in
            do {
                let savedURL = try ShareReportExporter.export(session: session, hardwareProfile: appState.hardwareProfile, to: url)
                shareMessage = "\(L10n.t("分享图已导出"))：\(savedURL.path)"
            } catch {
                shareMessage = "\(L10n.t("分享图导出失败"))：\(error.localizedDescription)"
            }
            isExportingShareImage = false
        }
    }

    private func stabilityTint(_ level: StabilityAssessmentLevel) -> Color {
        switch level {
        case .stable: .green
        case .slightRegression: .orange
        case .possibleThermalLimit: .red
        case .insufficientData: .gray
        }
    }
}

struct StabilityDetailStrip: View {
    var report: PerformanceThermalReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                title: "持续性能释放稳定程度",
                systemImage: "speedometer",
                help: "该判断比较测试前段与后段的总功耗、P 核频率、GPU 频率、综合温度、macOS 热状态和降级样本比例。它是趋势提示，不是实验室绝对结论。"
            )
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                compactMetric("功耗回落", percent(report.stability.powerDropPercent))
                compactMetric("P 核回落", percent(report.stability.pFrequencyDropPercent))
                compactMetric("GPU 回落", percent(report.stability.gpuFrequencyDropPercent))
                compactMetric("温度变化", celsiusDelta(report.stability.temperatureRiseC))
                compactMetric("降级比例", Formatters.percent(report.stability.degradedSampleRatio * 100))
                compactMetric("有效样本", "\(report.validSampleCount ?? max(0, report.sampleCount - report.degradedSampleCount)) / \(report.sampleCount)")
            }
        }
        .padding(14)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func compactMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.t(title))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(L10n.t(value))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "不可用" }
        return String(format: "%.0f%%", value)
    }

    private func celsiusDelta(_ value: Double?) -> String {
        guard let value else { return "不可用" }
        let sign = value >= 0 ? "+" : ""
        return String(format: "%@%.1f °C", sign, value)
    }
}

struct SessionSampleArchiveCard: View {
    @EnvironmentObject private var appState: AppState
    var session: StressSessionSummary
    @State private var actionMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "采样保存",
                systemImage: "tablecells",
                help: "历史 JSON 只保存轻量曲线样本，避免文件过大；完整采样会另外保存为 CSV，适合复盘 30 分钟测试的全程数据。"
            )
            KeyValueRow(title: "完整采样", value: "\(session.sampleCount) 个样本")
            KeyValueRow(title: "降级样本", value: "\(session.degradedSampleCount) 个样本")
            KeyValueRow(title: "历史曲线样本", value: "\(savedCurveSampleCount) / \(session.sampleCount) 个样本")
            KeyValueRow(title: "完整 CSV", value: csvStateText, monospaced: fullCSVFileExists)

            HStack {
                Button {
                    openFullCSV()
                } label: {
                    Label("打开完整 CSV", systemImage: "doc.text.magnifyingglass")
                }
                .disabled(!fullCSVFileExists)

                Button {
                    exportFullCSV()
                } label: {
                    Label("导出完整 CSV", systemImage: "square.and.arrow.down")
                }
            }

            if let actionMessage {
                Text(actionMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .labGlassCard()
    }

    private var savedCurveSampleCount: Int {
        session.savedCurveSampleCount ?? session.samples.count
    }

    private var fullCSVURL: URL? {
        appState.store.fullSamplesCSVURL(for: session)
    }

    private var fullCSVFileExists: Bool {
        guard let fullCSVURL else { return false }
        return FileManager.default.fileExists(atPath: fullCSVURL.path)
    }

    private var csvStateText: String {
        if let fullCSVURL, fullCSVFileExists {
            return fullCSVURL.path
        }
        if session.fullSampleCSVPath != nil || session.fullSampleCSVRelativePath != nil {
            return "CSV 文件未找到，可重新导出历史曲线样本"
        }
        return "旧记录未自动保存完整 CSV"
    }

    private func openFullCSV() {
        guard let fullCSVURL, fullCSVFileExists else {
            actionMessage = L10n.t("完整 CSV 文件未找到。")
            return
        }
        NSWorkspace.shared.open(fullCSVURL)
    }

    private func exportFullCSV() {
        let panel = NSSavePanel()
        panel.title = L10n.t("导出完整 CSV")
        panel.nameFieldStringValue = TelemetryCSVExporter.suggestedFilename(
            startedAt: session.startedAt,
            mode: session.configuration.mode
        )
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let exportKind = try appState.store.copyFullSamplesCSV(for: session, to: url)
            if exportKind == .fullSamples {
                actionMessage = "\(L10n.t("完整 CSV 已导出"))：\(url.path)"
            } else if session.fullSampleCSVPath == nil && session.fullSampleCSVRelativePath == nil {
                actionMessage = L10n.t("旧记录没有完整 CSV，已导出历史曲线样本。")
            } else {
                actionMessage = L10n.t("完整 CSV 文件缺失，已导出历史曲线样本。")
            }
        } catch {
            actionMessage = "\(L10n.t("CSV 导出失败"))：\(error.localizedDescription)"
        }
    }
}
