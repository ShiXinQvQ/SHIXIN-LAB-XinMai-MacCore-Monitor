import ShixinStressPowerCore
import SwiftUI

struct StressTestView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StressHeader()
                StressSafetyCard()
                StressControlCard()
                LiveSessionCard()
            }
            .padding(22)
        }
    }
}

struct StressHeader: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                titleBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    StatusPill(text: appState.configuration.mode.title, systemImage: appState.configuration.mode.systemImage, tint: .orange)
                    actionButton
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                titleBlock
                HStack(spacing: 8) {
                    StatusPill(text: appState.configuration.mode.title, systemImage: appState.configuration.mode.systemImage, tint: .orange)
                    Spacer()
                    actionButton
                }
            }
        }
        .labGlassCard(padding: 16, cornerRadius: 18)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("压力测试")
                .font(.title2.weight(.semibold))
                .lineLimit(1)
            Text("CPU、Metal GPU 与联合烤机，带热状态保护")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if appState.phase == .stopping {
            Button {} label: {
                Label("正在停止", systemImage: "hourglass")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(true)
        } else if appState.isRunning {
            Button {
                appState.stopStress()
            } label: {
                Label("停止当前烤机", systemImage: "stop.circle.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        } else {
            Button {
                appState.requestStartStress()
            } label: {
                Label("开始烤机", systemImage: "play.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

struct StressSafetyCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "安全边界", systemImage: "lock.shield")
            ViewThatFits(in: .horizontal) {
                safetyGrid(columns: [
                    GridItem(.flexible(minimum: 185), spacing: 18),
                    GridItem(.flexible(minimum: 185), spacing: 18),
                    GridItem(.flexible(minimum: 185), spacing: 18)
                ])
                safetyGrid(columns: [
                    GridItem(.flexible(minimum: 240), spacing: 18),
                    GridItem(.flexible(minimum: 240), spacing: 18)
                ])
                safetyGrid(columns: [GridItem(.flexible(minimum: 240), spacing: 12)])
            }
            Text("长时间满载会让 Mac 发热、风扇升速、降频或快速耗电；本工具默认会在 Critical 热状态或 Serious 持续过久时自动停止。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .labGlassCard()
    }

    private func safetyGrid(columns: [GridItem]) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            safetyItem("受控负载", "只运行 CPU worker 与 Metal compute", "cpu")
            safetyItem("自动停止", automaticStopSummary, "stop.circle")
            safetyItem("采样降级", "受限时保留 thermalState", "gauge.with.dots.needle.50percent")
            safetyItem("本地完成", "不联网，不上传硬件数据", "network.slash")
            safetyItem("不碰磁盘", "不执行写盘、修复或清理命令", "internaldrive")
            safetyItem("历史可追溯", "保存 session 摘要与日志", "doc.text.magnifyingglass")
        }
    }

    private var automaticStopSummary: String {
        appState.configuration.stopOnCriticalThermalState
            ? "到时、Critical 或 Serious 超时停止"
            : "到时或 Serious 超时停止"
    }

    private func safetyItem(_ title: String, _ subtitle: String, _ image: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: image)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t(title))
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(L10n.t(subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StressControlCard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "测试设置", systemImage: "slider.horizontal.3")
            modeDurationRow
            modeSpecificLoadControls
            thermalProtectionRow

            if appState.phase == .stopping {
                Button {} label: {
                    Label("正在停止", systemImage: "hourglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(true)
            } else if appState.isRunning {
                Button {
                    appState.stopStress()
                } label: {
                    Label("停止当前烤机", systemImage: "stop.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            } else {
                Button {
                    appState.requestStartStress()
                } label: {
                    Label("开始烤机", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .labGlassCard()
    }

    private var modeSpecificLoadControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            if appState.configuration.mode != .gpu {
                workerStepper
                    .transition(modeControlTransition)
            }
            if appState.configuration.mode != .cpu {
                gpuSettings
                    .transition(modeControlTransition)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(modeControlAnimation, value: appState.configuration.mode)
    }

    private var modeControlAnimation: Animation? {
        reduceMotion
            ? nil
            : .snappy(duration: 0.24, extraBounce: 0)
    }

    private var modeControlTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .offset(y: 4)),
            removal: .opacity
                .combined(with: .offset(y: -2))
        )
    }

    private var modeDurationRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                compactFormField(
                    title: "模式",
                    help: "选择这次压力测试压哪一部分：CPU 只压处理器，GPU 只压 Metal compute，CPU + GPU 会联合烤机。",
                    controlWidth: 260
                ) {
                    modePicker
                }
                compactFormField(
                    title: "时长",
                    help: "到达设定时长后会自动停止，并保存历史记录。",
                    controlWidth: 318,
                    labelAlignment: .trailing
                ) {
                    durationPicker
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 12) {
                formField(title: "模式", help: "选择这次压力测试压哪一部分：CPU 只压处理器，GPU 只压 Metal compute，CPU + GPU 会联合烤机。") {
                    modePicker
                }
                formField(title: "时长", help: "到达设定时长后会自动停止，并保存历史记录。") {
                    durationPicker
                }
            }
        }
    }

    private var modePicker: some View {
        Picker("模式", selection: modeSelection) {
            ForEach(StressMode.allCases) { mode in
                Text(L10n.t(mode.title)).tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .disabled(appState.isRunning)
        .accessibilityLabel(L10n.t("模式"))
        .accessibilityValue(L10n.t(appState.configuration.mode.title))
    }

    private var modeSelection: Binding<StressMode> {
        Binding {
            appState.configuration.mode
        } set: { newMode in
            guard newMode != appState.configuration.mode else { return }
            appState.configuration.mode = newMode
        }
    }

    private var durationPicker: some View {
        Picker("时长", selection: $appState.configuration.durationSeconds) {
            Text("1 分钟").tag(TimeInterval(60))
            Text("5 分钟").tag(TimeInterval(300))
            Text("10 分钟").tag(TimeInterval(600))
            Text("30 分钟").tag(TimeInterval(1800))
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .disabled(appState.isRunning)
        .accessibilityLabel(L10n.t("时长"))
        .accessibilityValue(Formatters.seconds(appState.configuration.durationSeconds))
    }

    private var workerStepper: some View {
        HStack(spacing: 10) {
            settingLabel(
                "CPU Workers",
                help: "每个 worker 都是一条 CPU 原生浮点压力线程。拉到逻辑核心数时功耗最高；新版会在小批次之间让出调度，保证停止和采样仍能响应。"
            )
            Spacer(minLength: 18)
            Text("\(appState.configuration.cpuWorkers)")
                .font(.callout.monospacedDigit())
                .frame(width: 64, alignment: .trailing)
            Stepper("CPU Workers", value: $appState.configuration.cpuWorkers, in: 1...max(1, ProcessInfo.processInfo.processorCount))
                .labelsHidden()
                .accessibilityLabel(L10n.t("CPU Workers"))
                .accessibilityValue("\(appState.configuration.cpuWorkers)")
        }
        .disabled(appState.isRunning)
    }

    private var gpuSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                settingLabel(
                    "GPU Work Items",
                    help: "一次提交给 Metal compute 的并行工作量。数值越高，GPU 同时处理的数据越多，显存与调度压力也会更高。"
                )
                Slider(value: gpuWorkItemsBinding, in: 262_144...2_097_152, step: 262_144)
                    .disabled(appState.isRunning)
                    .accessibilityLabel(L10n.t("GPU Work Items"))
                    .accessibilityValue("\(appState.configuration.gpuWorkItems / 1024)K")
                Text("\(appState.configuration.gpuWorkItems / 1024)K")
                    .font(.callout.monospacedDigit())
                    .frame(width: 72, alignment: .trailing)
            }
            HStack {
                settingLabel(
                    "GPU Iterations",
                    help: "每个 GPU work item 内部重复计算的次数。数值越高，单次 Metal 任务越重，适合提高持续 GPU 负载。"
                )
                Slider(value: gpuIterationsBinding, in: 512...4096, step: 256)
                    .disabled(appState.isRunning)
                    .accessibilityLabel(L10n.t("GPU Iterations"))
                    .accessibilityValue("\(appState.configuration.gpuIterations)")
                Text("\(appState.configuration.gpuIterations)")
                    .font(.callout.monospacedDigit())
                    .frame(width: 72, alignment: .trailing)
            }
        }
    }

    private var thermalProtectionRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 24) {
                criticalToggle
                    .frame(maxWidth: .infinity, alignment: .leading)
                seriousSlider
                    .frame(maxWidth: .infinity)
            }
            VStack(alignment: .leading, spacing: 12) {
                criticalToggle
                seriousSlider
            }
        }
    }

    private var criticalToggle: some View {
        Toggle(isOn: $appState.configuration.stopOnCriticalThermalState) {
            HStack(spacing: 5) {
                Text(L10n.t("Critical 热状态自动停止"))
                InfoHelpButton(
                    title: "Critical 热状态自动停止",
                    message: "macOS 把系统热状态分为 Nominal、Fair、Serious、Critical。开启后，一旦进入 Critical，本工具会停止负载，避免继续加压。"
                )
            }
        }
        .disabled(appState.isRunning)
    }

    private var seriousSlider: some View {
        HStack(spacing: 12) {
            settingLabel(
                "Serious 宽限",
                help: "Serious 表示系统已经明显热压。这里设置允许 Serious 持续多久；超过后会自动停止，适合长时间烤机时做保护。"
            )
            Slider(value: $appState.configuration.thermalSeriousGraceSeconds, in: 15...300, step: 5)
                .disabled(appState.isRunning)
                .accessibilityLabel(L10n.t("Serious 宽限"))
                .accessibilityValue(thermalSeriousGraceText)
            Text(thermalSeriousGraceText)
                .font(.callout.monospacedDigit())
                .frame(width: 64, alignment: .trailing)
        }
    }

    private var thermalSeriousGraceText: String {
        "\(Int(appState.configuration.thermalSeriousGraceSeconds)) \(L10n.t("秒"))"
    }

    private var gpuWorkItemsBinding: Binding<Double> {
        Binding(
            get: { Double(appState.configuration.gpuWorkItems) },
            set: { appState.configuration.gpuWorkItems = Int($0) }
        )
    }

    private var gpuIterationsBinding: Binding<Double> {
        Binding(
            get: { Double(appState.configuration.gpuIterations) },
            set: { appState.configuration.gpuIterations = Int($0) }
        )
    }

    private func settingLabel(_ title: String, help: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(L10n.t(title))
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
            InfoHelpButton(title: title, message: help)
        }
        .frame(minWidth: 130, alignment: .leading)
    }

    private func compactFormField<Content: View>(
        title: String,
        help: String,
        controlWidth: CGFloat,
        labelAlignment: Alignment = .leading,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(L10n.t(title))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                InfoHelpButton(title: title, message: help)
            }
            .frame(width: 64, alignment: labelAlignment)

            content()
                .frame(width: controlWidth)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func formField<Content: View>(title: String, help: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            settingLabel(title, help: help)
            content()
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

struct LiveSessionCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.liveSession != nil {
                TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                    content
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "当前 Session", systemImage: "waveform.path.ecg")
            if let session = appState.liveSession {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                    MetricTile(title: "运行时间", value: Formatters.seconds(session.elapsedSeconds), detail: "Elapsed", systemImage: "timer", tint: .cyan)
                    MetricTile(title: "峰值功耗", value: Formatters.watts(session.peakPowerW), detail: "Peak", systemImage: "bolt.fill", tint: .yellow)
                    switch session.configuration.mode {
                    case .cpu:
                        MetricTile(title: "CPU 峰值功耗", value: Formatters.watts(session.peakCPUPowerW), detail: "CPU Peak", systemImage: "cpu", tint: .green)
                    case .gpu:
                        MetricTile(title: "GPU 峰值功耗", value: Formatters.watts(session.peakGPUPowerW), detail: "GPU Peak", systemImage: "rectangle.3.group", tint: .blue)
                    case .combined:
                        MetricTile(title: "CPU 峰值功耗", value: Formatters.watts(session.peakCPUPowerW), detail: "CPU Peak", systemImage: "cpu", tint: .green)
                        MetricTile(title: "GPU 峰值功耗", value: Formatters.watts(session.peakGPUPowerW), detail: "GPU Peak", systemImage: "rectangle.3.group", tint: .blue)
                    }
                    MetricTile(title: "60 秒持续", value: Formatters.watts(session.sustainedPower60sW), detail: "Rolling Average", systemImage: "chart.line.uptrend.xyaxis", tint: .purple)
                    if session.configuration.mode != .gpu {
                        MetricTile(title: "CPU 峰值温度", value: Formatters.celsius(session.peakCPUTemperatureC), detail: "CPU Peak", systemImage: "thermometer.high", tint: .red)
                    }
                    if session.configuration.mode != .cpu {
                        MetricTile(title: "GPU 峰值温度", value: Formatters.celsius(session.peakGPUTemperatureC), detail: "GPU Peak", systemImage: "thermometer.medium", tint: .pink)
                    }
                    MetricTile(title: "芯片峰值温度", value: Formatters.celsius(session.peakSoCTemperatureC), detail: "SoC Peak", systemImage: "sensor.tag.radiowaves.forward", tint: .teal)
                    MetricTile(title: "最差热状态", value: session.worstThermalState, detail: "Worst Thermal", systemImage: "thermometer.sun.fill", tint: session.worstThermalState.thermalTint)
                }
                if session.logMessages.isEmpty {
                    Text("Session 日志会在这里显示。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(session.logMessages.prefix(8), id: \.self) { line in
                        Text(L10n.t(line))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            } else {
                ContentUnavailableView("没有正在运行的 Session", systemImage: "flame", description: Text("开始一次 CPU、GPU 或联合烤机后，这里会显示实时摘要和安全日志。"))
                    .frame(maxWidth: .infinity, minHeight: 220)
            }
        }
        .labGlassCard()
    }
}
