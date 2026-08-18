import ShixinStressPowerCore
import SwiftUI

struct HelperOnboardingSheet: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.blue.opacity(0.16))
                    Image(
                        systemName: appState.helperStatus.needsUpdate
                            ? "arrow.triangle.2.circlepath.circle.fill"
                            : "cpu.fill"
                    )
                        .font(.system(size: 36, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.blue)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.t(appState.helperStatus.needsUpdate ? "更新 Helper" : "安装 Helper"))
                        .font(.title2.weight(.semibold))
                    Text(L10n.t("Helper 提供功耗、频率与热状态的系统级采样，并读取 AppleSMC/HID 温度、风扇及扩展传感器。由 launchd 在本机管理，App 仅通过本地 socket 读取只读数据。"))
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .fontWeight(.regular)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            helperFeatureGrid

            if let message = appState.helperActionMessage {
                Text(L10n.t(message))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(appState.helperStatus.isUsable ? .green : .secondary)
                    .textSelection(.enabled)
            }

            HStack(spacing: 10) {
                Button {
                    appState.dismissHelperOnboarding()
                } label: {
                    Text(L10n.t("稍后"))
                        .frame(minWidth: 86)
                }
                .buttonStyle(.bordered)
                .disabled(appState.helperActionInProgress)

                Spacer()

                Button {
                    appState.installHelper(fromOnboarding: true)
                } label: {
                    Label(L10n.t(helperButtonTitle), systemImage: "arrow.down.app.fill")
                        .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(appState.helperActionInProgress)
            }
        }
        .padding(24)
        .frame(width: 620)
        .preferredColorScheme(.dark)
        .presentationSizing(.fitted)
    }

    private var helperButtonTitle: String {
        if appState.helperActionInProgress {
            return appState.helperStatus.needsUpdate ? "正在更新" : "正在安装"
        }
        return appState.helperStatus.needsUpdate ? "更新 Helper" : "安装 Helper"
    }

    private var helperFeatureGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            alignment: .leading,
            spacing: 12
        ) {
            helperFeature("一次授权", "安装时完成管理员授权，之后由系统自动运行", "lock.open.fill", .blue)
            helperFeature("本机只读", "仅在本机读取传感器，不联网也不上传数据", "network.slash", .green)
            helperFeature("温度协同", "App 与 Helper 协同补全 CPU、GPU 温度采样", "thermometer.medium", .red)
            helperFeature("随时管理", "可在设置中更新、修复、卸载并检查状态", "wrench.and.screwdriver.fill", .indigo)
        }
    }

    private func helperFeature(_ title: String, _ subtitle: String, _ image: String, _ tint: Color) -> some View {
        HStack(alignment: .center, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.15))
                Image(systemName: image)
                    .font(.title3.weight(.medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t(title))
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text(L10n.t(subtitle))
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .fontWeight(.regular)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(
            Color.white.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        }
    }
}

struct StressStartConfirmationSheet: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(.orange.opacity(0.09))
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(.orange.opacity(0.18), lineWidth: 1)
                    Image(systemName: "flame")
                        .font(.system(size: 26, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.orange)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 5) {
                    Text(String(format: L10n.t("开始 %@ 烤机？"), L10n.t(appState.configuration.mode.title)))
                        .font(.title2.weight(.semibold))
                    Text(L10n.t("确认后会立即拉高负载，Mac 可能快速升温、风扇升速、降频或耗电增加。"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                confirmationMetricPanel
                    .frame(maxWidth: .infinity)
                safetySummaryPanel
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 10) {
                Button {
                    appState.cancelStartStress()
                } label: {
                    Text(L10n.t("取消"))
                        .frame(minWidth: 86)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    appState.confirmStartStress()
                } label: {
                    Label(L10n.t("确认开始烤机"), systemImage: "play.circle.fill")
                        .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 740)
        .preferredColorScheme(.dark)
        .presentationSizing(.fitted)
    }

    private var gpuLoadText: String {
        switch appState.configuration.mode {
        case .cpu:
            return "关闭"
        case .gpu, .combined:
            return "\(appState.configuration.gpuWorkItems / 1024)K / \(appState.configuration.gpuIterations)"
        }
    }

    private var confirmationMetricPanel: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ],
            spacing: 8
        ) {
            confirmationTile("模式", appState.configuration.mode.title, modeDetail, "flame.fill", .orange)
            confirmationTile("时长", Formatters.seconds(appState.configuration.durationSeconds), "到时自动停止", "timer", .cyan)
            confirmationTile("CPU Workers", cpuWorkerText, cpuWorkerDetail, "cpu", .green)
            confirmationTile("GPU 负载", gpuLoadText, gpuLoadDetail, "rectangle.3.group", .blue)
        }
    }

    private var safetySummaryPanel: some View {
        VStack(alignment: .leading, spacing: 13) {
            helperRow("保护停止", protectionSummary, "shield.checkered")
            helperRow("Helper 状态", helperStatusSummary, "checkmark.seal.fill")
            helperRow("手动控制", "运行期间可随时安全停止当前测试。", "hand.raised.circle.fill")
            helperRow("本地记录", "结束后自动保存摘要与完整采样 CSV。", "doc.text.fill")
        }
        .frame(maxWidth: .infinity, minHeight: 188, alignment: .center)
        .labGlassCard(padding: 12, cornerRadius: 16)
    }

    private var modeDetail: String {
        switch appState.configuration.mode {
        case .cpu:
            return "原生 CPU 负载"
        case .gpu:
            return "Metal GPU 负载"
        case .combined:
            return "CPU + Metal GPU"
        }
    }

    private var cpuWorkerText: String {
        appState.configuration.mode == .gpu
            ? "关闭"
            : "\(appState.configuration.cpuWorkers) \(L10n.t("核心"))"
    }

    private var cpuWorkerDetail: String {
        appState.configuration.mode == .gpu
            ? "当前模式不启用"
            : "原生计算线程"
    }

    private var gpuLoadDetail: String {
        appState.configuration.mode == .cpu
            ? "当前模式不启用"
            : "Metal 任务规模"
    }

    private var protectionSummary: String {
        if appState.configuration.stopOnCriticalThermalState {
            return "Critical 或 Serious 超时会自动停止。"
        }
        return "Critical 停止已关闭；Serious 超时仍会停止。"
    }

    private var helperStatusSummary: String {
        if appState.helperStatus.needsUpdate {
            return "Helper 版本不一致，更新后再进行长时间测试。"
        }
        return appState.helperStatus.isOperational
            ? "优先读取 powermetrics 与 HID 温度。"
            : "Helper 受限，功耗与频率会降级显示。"
    }

    private func confirmationTile(
        _ title: String,
        _ value: String,
        _ detail: String,
        _ image: String,
        _ tint: Color
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: image)
                .font(.system(size: 25, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t(value))
                    .font(.headline.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(L10n.t(detail))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 82)
        .labGlassCard(padding: 10, cornerRadius: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(L10n.t(title))：\(L10n.t(value))，\(L10n.t(detail))"
        )
    }

    private func helperRow(_ title: String, _ subtitle: String, _ image: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.green.opacity(0.16))
                Image(systemName: image)
                    .font(.body.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.green)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t(title))
                    .font(.callout.weight(.semibold))
                Text(L10n.t(subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct PerformanceReportReadySheet: View {
    var session: StressSessionSummary?
    var onDismiss: () -> Void
    var onViewReport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.green.opacity(0.16))
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 34, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.green)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.t("性能热力报告已生成"))
                        .font(.title2.weight(.semibold))
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                reportRow("历史已保存", "Session 摘要、轻量曲线和完整 CSV 已写入本机数据目录。", "clock.arrow.circlepath")
                reportRow("报告已归档", "性能热力报告可在历史详情中查看，也可导出分享图。", "chart.xyaxis.line")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .labGlassCard(padding: 14, cornerRadius: 16)

            HStack(spacing: 10) {
                Button {
                    onDismiss()
                } label: {
                    Text(L10n.t("已知晓"))
                        .frame(minWidth: 92)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    onViewReport()
                } label: {
                    Label(L10n.t("查看性能热力报告"), systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .frame(width: 432)
        .preferredColorScheme(.dark)
        .presentationSizing(.fitted)
    }

    private var subtitle: String {
        guard let session else {
            return L10n.t("压力测试已结束，性能热力报告已保存到历史记录。")
        }
        return "\(L10n.t(session.configuration.mode.title)) · \(Formatters.seconds(session.durationSeconds)) · \(Formatters.shortDate(session.endedAt))"
    }

    private func reportRow(_ title: String, _ subtitle: String, _ image: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: image)
                .font(.callout.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.cyan)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t(title))
                    .font(.callout.weight(.semibold))
                Text(L10n.t(subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
