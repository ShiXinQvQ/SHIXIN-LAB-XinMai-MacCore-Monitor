import AppKit
import ShixinNetworkDiagnosticsCore
import ShixinStressPowerCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PrivacySettingsCard()
                LanguageSettingsCard()
                PermissionCard()
                StorageCard()
                AboutCard()
            }
            .padding(22)
        }
    }
}

struct PrivacySettingsCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "隐私与显示", systemImage: "lock.shield")
            Toggle(isOn: showPrivateIdentifiersBinding) {
                Text("显示完整设备标识")
            }
            Text("设备序列号、Provisioning UDID 与平台 UUID 默认脱敏，仅在你主动开启后于本机显示；App 不会后台上传硬件数据或测试记录，也不读取或保存管理员密码。测速与国际诊断仅在你主动开始时联网；公网/IP 信誉查询会另行说明第三方可见当前公网 IP，结果与其他历史均只保存在本机。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .labSettingsCard()
    }

    private var showPrivateIdentifiersBinding: Binding<Bool> {
        Binding {
            appState.showPrivateHardwareIdentifiers
        } set: { newValue in
            appState.setShowPrivateHardwareIdentifiers(newValue)
        }
    }
}

struct LanguageSettingsCard: View {
    @AppStorage("appLanguagePreference") private var selectedRawValue = AppLanguagePreference.system.rawValue
    @State private var showsRestartHint = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "语言", systemImage: "globe")
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("界面语言")
                        .font(.callout.weight(.medium))
                    Text("默认跟随 macOS 当前语言。更改后点击下方按钮重启 App 生效。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("界面语言", selection: $selectedRawValue) {
                    ForEach(AppLanguagePreference.allCases) { language in
                        Text(language.title).tag(language.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 150)
            }
            if showsRestartHint {
                Button {
                    AppRestarter.restartApp()
                } label: {
                    Label("重启并应用语言", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
        .labSettingsCard()
        .onChange(of: selectedRawValue) { _, newValue in
            applyLanguagePreference(newValue)
            showsRestartHint = true
        }
    }

    private func applyLanguagePreference(_ rawValue: String) {
        let preference = AppLanguagePreference(rawValue: rawValue) ?? .system
        AppLanguageController.apply(preference)
    }
}

struct PermissionCard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsTechnicalDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                SectionHeader(
                    title: "高级权限",
                    systemImage: "key.radiowaves.forward",
                    help: "仅安装、更新或修复 Helper 时需要 macOS 管理员授权。App 平时不以 root 运行；Helper 只提供本机只读采样，不联网、不接受任意命令，数据不可用时界面会明确标注。"
                )
                StatusPill(text: appState.helperStatus.title, systemImage: "key.fill", tint: helperTint)
                    .fixedSize(horizontal: true, vertical: false)
            }
            Text("Helper 通过本地 Unix socket 提供 500 ms 只读采样，不联网，也不接受任意命令。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            KeyValueRow(title: "当前状态", value: appState.permissionMessage)
            KeyValueRow(title: "Helper 状态", value: compactHelperStatus)
            KeyValueRow(title: "安装位置", value: HelperConstants.installedHelperPath, monospaced: true)
            KeyValueRow(title: "LaunchDaemon", value: HelperConstants.launchDaemonPath, monospaced: true)
            if showsTechnicalDetails {
                VStack(alignment: .leading, spacing: 12) {
                    KeyValueRow(title: "本地 socket", value: HelperConstants.socketPath, monospaced: true)
                    KeyValueRow(title: "powermetrics", value: "/usr/bin/powermetrics", monospaced: true)
                    KeyValueRow(title: "采样器", value: "500 ms stream + AppleSMC/HID cache", monospaced: true)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    helperActionButtons
                    Spacer(minLength: 12)
                    technicalDetailsButton
                }
                VStack(alignment: .leading, spacing: 8) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                        helperActionButtons
                    }
                    technicalDetailsButton
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            if let message = appState.helperActionMessage {
                Text(L10n.t(message))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

        }
        .labSettingsCard()
    }

    private var technicalDetailsButton: some View {
        Button {
            if reduceMotion {
                showsTechnicalDetails.toggle()
            } else {
                withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
                    showsTechnicalDetails.toggle()
                }
            }
        } label: {
            Label(
                showsTechnicalDetails ? "收起技术详情" : "展开技术详情",
                systemImage: showsTechnicalDetails ? "chevron.up.circle.fill" : "chevron.down.circle.fill"
            )
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityValue(L10n.t(showsTechnicalDetails ? "已展开" : "已收起"))
    }

    private var helperTint: Color {
        if appState.helperStatus.isUsable { return .green }
        if appState.helperStatus.needsUpdate { return .blue }
        return .orange
    }

    private var compactHelperStatus: String {
        let version = appState.helperStatus.helperVersion ?? L10n.t("未知版本")
        let compatibility: String
        if appState.helperStatus.isUsable {
            compatibility = L10n.t("版本一致")
        } else if appState.helperStatus.needsUpdate {
            compatibility = L10n.t("需要更新")
        } else {
            compatibility = L10n.t("状态需检查")
        }

        let sampling: String
        switch appState.helperStatus.samplingState {
        case "idle":
            sampling = L10n.t("按需待机")
        case "ready":
            sampling = L10n.t("采样正常")
        case "starting", "restarting":
            sampling = L10n.t("正在恢复")
        default:
            sampling = L10n.t("状态未知")
        }
        return "\(version) · \(compatibility) · \(sampling)"
    }

    @ViewBuilder
    private var helperActionButtons: some View {
        Button {
            appState.installHelper()
        } label: {
            Label(appState.helperStatus.needsUpdate ? "更新 Helper" : "安装 Helper", systemImage: "plus.circle")
        }
        .disabled(appState.helperActionInProgress)

        Button {
            appState.uninstallHelper()
        } label: {
            Label("卸载 Helper", systemImage: "minus.circle")
        }
        .disabled(appState.helperActionInProgress)

        Button {
            appState.repairHelper()
        } label: {
            Label("Helper 修复工具", systemImage: "wrench.and.screwdriver.fill")
        }
        .disabled(appState.helperActionInProgress)

        Button {
            appState.refreshHelperStatus()
        } label: {
            Label("刷新状态", systemImage: "arrow.clockwise")
        }
        .disabled(appState.helperActionInProgress)
    }
}

enum AppLanguagePreference: String, CaseIterable, Identifiable {
    case system
    case zhHans
    case en
    case ja

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: L10n.t("跟随系统")
        case .zhHans: L10n.t("简体中文")
        case .en: "English"
        case .ja: "日本語"
        }
    }

    var appleLanguages: [String]? {
        switch self {
        case .system: nil
        case .zhHans: ["zh-Hans"]
        case .en: ["en"]
        case .ja: ["ja"]
        }
    }
}

enum AppLanguageController {
    static func apply(_ preference: AppLanguagePreference) {
        if let languages = preference.appleLanguages {
            UserDefaults.standard.set(languages, forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }
}

enum AppRestarter {
    static func restartApp() {
        let bundlePath = Bundle.main.bundlePath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "sleep 0.7; exec /usr/bin/open \"$1\"",
            "shixin-app-restarter",
            bundlePath
        ]
        try? process.run()
        NSApp.terminate(nil)
    }
}

struct StorageCard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsTechnicalDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "本地数据",
                systemImage: "folder",
                help: "压力测试历史、完整 CSV、网速历史、国际诊断历史与运行日志都保存在本机 Application Support 目录。国际诊断历史不保存完整公网 IP、SSID、BSSID 或 MAC；App 不会在后台上传这些文件。"
            )
            KeyValueRow(title: "Session 历史", value: appState.store.sessionsURL.path, monospaced: true)
            KeyValueRow(title: "完整 CSV", value: appState.store.sessionCSVDirectoryURL.path, monospaced: true)
            if showsTechnicalDetails {
                VStack(alignment: .leading, spacing: 12) {
                    KeyValueRow(title: "网速历史", value: networkHistoryURL.path, monospaced: true)
                    KeyValueRow(
                        title: "国际诊断历史",
                        value: networkDiagnosticsHistoryURL.path,
                        monospaced: true
                    )
                    KeyValueRow(title: "运行日志", value: appState.store.logURL.path, monospaced: true)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    storageActionButtons
                    Spacer(minLength: 12)
                    technicalDetailsButton
                }
                VStack(alignment: .leading, spacing: 8) {
                    storageActionButtons
                    technicalDetailsButton
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .labSettingsCard()
    }

    private var storageActionButtons: some View {
        HStack(spacing: 8) {
            Button("打开数据目录") {
                NSWorkspace.shared.open(appState.store.appSupportURL)
            }
            Button("刷新历史") {
                appState.loadSessions()
            }
        }
    }

    private var technicalDetailsButton: some View {
        Button {
            if reduceMotion {
                showsTechnicalDetails.toggle()
            } else {
                withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
                    showsTechnicalDetails.toggle()
                }
            }
        } label: {
            Label(
                showsTechnicalDetails ? "收起技术详情" : "展开技术详情",
                systemImage: showsTechnicalDetails ? "chevron.up.circle.fill" : "chevron.down.circle.fill"
            )
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityValue(L10n.t(showsTechnicalDetails ? "已展开" : "已收起"))
    }

    private var networkHistoryURL: URL {
        NetworkSpeedHistoryStore(appSupportURL: appState.store.appSupportURL).historyURL
    }

    private var networkDiagnosticsHistoryURL: URL {
        NetworkDiagnosticsHistoryStore(
            appSupportURL: appState.store.appSupportURL
        ).historyURL
    }
}

struct AboutCard: View {
    @EnvironmentObject private var appState: AppState
    @State private var isGeneratingDiagnosticReport = false
    @State private var diagnosticMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "关于", systemImage: "info.circle")
            HStack(alignment: .center, spacing: 10) {
                AppIconPreview()
                    .offset(x: -4)

                VStack(alignment: .leading, spacing: 5) {
                    Text("SHIXIN LAB · 「芯脉」 MacCore Monitor")
                        .font(.title3.weight(.semibold))
                    Text("Apple Silicon 压力测试与硬件监测")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button {
                        NSWorkspace.shared.open(URL(string: "https://shixinqvq.com/")!)
                    } label: {
                        Label("访问 SHIXIN LAB 官网", systemImage: "globe")
                    }
                    .buttonStyle(.link)
                }
            }

            KeyValueRow(title: "Bundle ID", value: bundleIdentifier, monospaced: true)
            KeyValueRow(
                title: "产品版本",
                value: "\(ReleaseConstants.appVersion) · \(L10n.t("构建")) \(ReleaseConstants.appBuild)"
            )
            KeyValueRow(title: "Helper", value: HelperConstants.helperVersion)
            KeyValueRow(title: "系统要求", value: L10n.t("macOS 15 或更高版本 · Apple Silicon"))
            KeyValueRow(title: "数据口径", value: L10n.t("功耗与频率为系统估算值"))

            HStack(alignment: .bottom, spacing: 12) {
                HStack(spacing: 10) {
                    diagnosticReportButton
                    copyVersionButton
                    openLogButton
                }
                .fixedSize(horizontal: true, vertical: false)

                if let diagnosticMessage {
                    Text(L10n.t(diagnosticMessage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .textSelection(.enabled)
                        .help(L10n.t(diagnosticMessage))
                }
            }

            Divider().opacity(0.25)

            VStack(alignment: .leading, spacing: 4) {
                Text("专为 Apple Silicon Mac 设计的本机压力测试与硬件监测工具：提供受控 CPU/Metal GPU 负载，以及 powermetrics、AppleSMC/HID 与 SMART 只读采样。")
                Text("曲线、完整 CSV、历史与性能热力报告均留在本机；测试全程受 macOS 热状态与采样中断保护。")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .labSettingsCard()
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.shixinqvq.shixinlab.macstresspower"
    }

    private var diagnosticReportButton: some View {
        Button {
            generateDiagnosticReport()
        } label: {
            Label(isGeneratingDiagnosticReport ? "正在生成诊断报告..." : "生成诊断报告", systemImage: "stethoscope")
        }
        .buttonStyle(.borderedProminent)
        .disabled(isGeneratingDiagnosticReport)
    }

    private var copyVersionButton: some View {
        Button {
            copyVersionInformation()
        } label: {
            Label("复制版本信息", systemImage: "doc.on.doc")
        }
        .buttonStyle(.bordered)
    }

    private var openLogButton: some View {
        Button {
            openRuntimeLog()
        } label: {
            Label("打开运行日志", systemImage: "doc.text.magnifyingglass")
        }
        .buttonStyle(.bordered)
    }

    private func copyVersionInformation() {
        let text = """
        SHIXIN LAB · 「芯脉」 MacCore Monitor
        \(L10n.t("产品版本")): \(ReleaseConstants.appVersion) · \(L10n.t("构建")) \(ReleaseConstants.appBuild)
        Helper: \(HelperConstants.helperVersion)
        Bundle ID: \(bundleIdentifier)
        \(L10n.t("系统要求")): \(L10n.t("macOS 15 或更高版本 · Apple Silicon"))
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        diagnosticMessage = "版本信息已复制"
    }

    private func openRuntimeLog() {
        let logURL = appState.store.logURL
        if FileManager.default.fileExists(atPath: logURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([logURL])
            diagnosticMessage = "已在 Finder 中定位运行日志"
        } else {
            NSWorkspace.shared.open(appState.store.appSupportURL)
            diagnosticMessage = "运行日志尚未生成，已打开数据目录"
        }
    }

    private func generateDiagnosticReport() {
        let panel = NSSavePanel()
        panel.title = L10n.t("导出诊断报告")
        panel.nameFieldStringValue = DiagnosticReportExporter.suggestedFilename()
        if let zipType = UTType(filenameExtension: "zip") {
            panel.allowedContentTypes = [zipType]
        }
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isGeneratingDiagnosticReport = true
        diagnosticMessage = L10n.t("正在生成诊断报告...")

        Task { @MainActor in
            do {
                let savedURL = try DiagnosticReportExporter.export(appState: appState, to: url)
                diagnosticMessage = "\(L10n.t("诊断报告已保存"))：\(savedURL.path)"
            } catch {
                diagnosticMessage = "\(L10n.t("诊断报告生成失败"))：\(error.localizedDescription)"
            }
            isGeneratingDiagnosticReport = false
        }
    }
}

private struct AppIconPreview: View {
    private static let displaySize: CGFloat = 96

    var body: some View {
        Group {
            if let image = Self.loadPreviewImage() {
                Image(nsImage: image)
                    .interpolation(.high)
                    .antialiased(true)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(1.18)
                    .accessibilityLabel("SHIXIN LAB · 「芯脉」")
            } else {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .accessibilityLabel("SHIXIN LAB · 「芯脉」")
            }
        }
        .frame(width: Self.displaySize, height: Self.displaySize)
        .clipped()
        .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
    }

    private static func loadPreviewImage() -> NSImage? {
        let candidates = [
            Bundle.main.url(forResource: "AppIconPreviewInApp", withExtension: "png"),
            Bundle.main.url(forResource: "AppIconPreview", withExtension: "png")
        ].compactMap { $0 }

        guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.size = NSSize(width: displaySize, height: displaySize)
        return image
    }
}
