import AppKit
import Foundation
import ShixinStressPowerCore

@MainActor
final class AppState: ObservableObject {
    @Published var configuration = StressConfiguration.default(logicalCPUs: ProcessInfo.processInfo.processorCount)
    @Published var phase: StressPhase = .idle
    var currentSample: TelemetrySample?
    var liveSamples: [TelemetrySample] = []
    @Published var liveSession: LiveSession?
    @Published var sessions: [StressSessionSummary] = []
    @Published var selectedSessionID: StressSessionSummary.ID?
    @Published var lastError: String?
    @Published var permissionMessage = "尚未采样"
    @Published var helperStatus = HelperInstallManager.status()
    @Published var helperActionInProgress = false
    @Published var helperActionMessage: String?
    @Published var shouldShowHelperOnboarding = false
    @Published var pendingStressConfirmation = false
    @Published var completedReportSessionID: StressSessionSummary.ID?
    @Published var hardwareProfile = HardwareProfile.loading
    @Published var showPrivateHardwareIdentifiers = UserDefaults.standard.bool(forKey: "com.shixinqvq.shixinlab.macstresspower.showPrivateHardwareIdentifiers")

    let store = HistoryStore()
    private let sampler = TelemetrySampler(intervalMilliseconds: 500)
    private let stressController = StressController()
    private var telemetryTask: Task<Void, Never>?
    private var safetyWatchdogTask: Task<Void, Never>?
    private var finishTask: Task<Void, Never>?
    private var seriousThermalBeganUptime: TimeInterval?
    private var lastTelemetryArrivalUptime: TimeInterval?
    private var lastTrustedTelemetryUptime: TimeInterval?
    private var stressStartedUptime: TimeInterval?
    private var lastHelperSampleSequence: UInt64?
    private var telemetryProtectionArmed = false
    private var latestSample: TelemetrySample?
    private var bufferedSamples: [TelemetrySample] = []
    private var publishesRealtimeSamples = true
    private var hardwareProfileRefreshGeneration: UInt64 = 0
    private let liveSampleLimit = 2_400
    private let initialHelperPromptKey = "com.shixinqvq.shixinlab.macstresspower.initialHelperPromptHandled"
    private static let showPrivateHardwareIdentifiersKey = "com.shixinqvq.shixinlab.macstresspower.showPrivateHardwareIdentifiers"

    var selectedSession: StressSessionSummary? {
        guard let selectedSessionID else { return sessions.first }
        return sessions.first { $0.id == selectedSessionID } ?? sessions.first
    }

    var completedReportSession: StressSessionSummary? {
        guard let completedReportSessionID else { return nil }
        return sessions.first { $0.id == completedReportSessionID }
    }

    var isRunning: Bool {
        phase == .running || phase == .starting || phase == .stopping
    }

    var needsAppExitCleanup: Bool {
        phase == .running || phase == .starting || phase == .stopping
    }

    var telemetryAgeSeconds: TimeInterval? {
        guard let arrival = lastTelemetryArrivalUptime else { return nil }
        return max(0, systemUptime - arrival) + (latestSample?.helperSampleAgeSeconds ?? 0)
    }

    var telemetryIsStale: Bool {
        (telemetryAgeSeconds ?? 0) > 2
    }

    func start() {
        loadSessions()
        refreshHelperStatus()
        refreshHardwareProfile()
        evaluateInitialHelperPrompt()
        guard telemetryTask == nil else { return }
        telemetryTask = Task(priority: .userInitiated) { [weak self] in
            await self?.telemetryLoop()
        }
        safetyWatchdogTask = Task(priority: .userInitiated) { [weak self] in
            await self?.safetyWatchdogLoop()
        }
    }

    func stopTelemetry() {
        telemetryTask?.cancel()
        telemetryTask = nil
        safetyWatchdogTask?.cancel()
        safetyWatchdogTask = nil
    }

    func loadSessions() {
        do {
            sessions = try store.loadSessions()
            selectedSessionID = sessions.first?.id
            if let recoveryNotice = store.lastRecoveryNotice {
                lastError = recoveryNotice
                try? store.appendLog(recoveryNotice)
            }
        } catch {
            lastError = "历史记录读取失败：\(error.localizedDescription)"
        }
    }

    func requestStartStress() {
        guard !isRunning else { return }
        pendingStressConfirmation = true
    }

    func confirmStartStress() {
        pendingStressConfirmation = false
        startStress()
    }

    func cancelStartStress() {
        pendingStressConfirmation = false
    }

    func dismissCompletedReportPrompt() {
        completedReportSessionID = nil
    }

    func startStress() {
        guard !isRunning else { return }
        lastError = nil
        completedReportSessionID = nil
        phase = .starting
        liveSession = LiveSession(
            configuration: configuration,
            environmentSnapshot: SessionEnvironmentSnapshot(hardwareProfile: hardwareProfile)
        )
        seriousThermalBeganUptime = nil
        stressStartedUptime = systemUptime
        let currentTelemetryTrusted = isCurrentTelemetryTrusted
        if !currentTelemetryTrusted {
            lastTrustedTelemetryUptime = nil
        }
        telemetryProtectionArmed = helperStatus.isOperational || currentTelemetryTrusted
        liveSession?.log("开始 \(configuration.mode.title) 烤机，目标时长 \(Formatters.seconds(configuration.durationSeconds))。")
        if !telemetryProtectionArmed {
            liveSession?.log("当前没有可用的 powermetrics 样本，采样中断保护暂未启用；热状态保护仍然有效。")
        }
        let startingSessionID = liveSession?.id

        Task {
            do {
                try await stressController.start(configuration: configuration)
                guard phase == .starting, liveSession?.id == startingSessionID else {
                    await stressController.stop()
                    return
                }
                phase = .running
                try? store.appendLog("Stress started: \(configuration.mode.title)")
            } catch {
                liveSession?.log("启动失败：\(error.localizedDescription)")
                lastError = error.localizedDescription
                phase = .failed
                telemetryProtectionArmed = false
                stressStartedUptime = nil
                await stressController.stop()
            }
        }
    }

    func stopStress(reason: StopReason = .user) {
        pendingStressConfirmation = false
        guard phase == .running || phase == .starting else { return }
        phase = .stopping
        finishTask = Task {
            await finishStress(reason: reason)
        }
    }

    func prepareForAppTermination() async {
        pendingStressConfirmation = false
        if phase == .running || phase == .starting {
            phase = .stopping
            finishTask = Task {
                await finishStress(reason: .appExit)
            }
        }
        if let finishTask {
            await finishTask.value
        }
        stopTelemetry()
    }

    func deleteSession(_ session: StressSessionSummary) {
        let updated = sessions.filter { $0.id != session.id }
        do {
            try store.saveSessions(updated)
            sessions = updated
            selectedSessionID = sessions.first?.id
        } catch {
            lastError = "删除历史失败：\(error.localizedDescription)"
        }
    }

    func refreshHelperStatus() {
        helperStatus = HelperInstallManager.status()
        if helperStatus.isUsable {
            shouldShowHelperOnboarding = false
            UserDefaults.standard.set(true, forKey: initialHelperPromptKey)
        }
    }

    func setRealtimePresentationActive(_ isActive: Bool) {
        guard publishesRealtimeSamples != isActive else { return }
        publishesRealtimeSamples = isActive
        guard isActive else { return }
        objectWillChange.send()
        currentSample = latestSample
        liveSamples = bufferedSamples
    }

    func refreshHardwareProfile() {
        hardwareProfileRefreshGeneration &+= 1
        let generation = hardwareProfileRefreshGeneration
        hardwareProfile = .loading
        let showPrivateHardwareIdentifiers = showPrivateHardwareIdentifiers
        let readTask = Task.detached(priority: .utility) {
            HardwareProfileReader.read(showPrivateIdentifiers: showPrivateHardwareIdentifiers)
        }
        Task { [weak self] in
            let profile = await readTask.value
            guard let self,
                  generation == hardwareProfileRefreshGeneration else { return }
            hardwareProfile = profile
        }
    }

    func setShowPrivateHardwareIdentifiers(_ show: Bool) {
        showPrivateHardwareIdentifiers = show
        UserDefaults.standard.set(show, forKey: Self.showPrivateHardwareIdentifiersKey)
        refreshHardwareProfile()
    }

    func installHelper(fromOnboarding: Bool = false) {
        helperActionInProgress = true
        helperActionMessage = "正在请求管理员权限安装 Helper..."
        if fromOnboarding {
            shouldShowHelperOnboarding = false
        }
        Task.detached {
            let result = Result { try HelperInstallManager.install() }
            await MainActor.run {
                switch result {
                case .success:
                    self.helperActionMessage = "Helper 安装完成。"
                    UserDefaults.standard.set(true, forKey: self.initialHelperPromptKey)
                case .failure(let error):
                    self.helperActionMessage = "Helper 安装失败：\(error.localizedDescription)"
                    self.lastError = error.localizedDescription
                    if fromOnboarding {
                        self.shouldShowHelperOnboarding = true
                    }
                }
                self.refreshHelperStatus()
                self.helperActionInProgress = false
            }
        }
    }

    func uninstallHelper() {
        helperActionInProgress = true
        helperActionMessage = "正在请求管理员权限卸载 Helper..."
        Task.detached {
            let result = Result { try HelperInstallManager.uninstall() }
            await MainActor.run {
                switch result {
                case .success:
                    self.helperActionMessage = "Helper 已卸载。"
                case .failure(let error):
                    self.helperActionMessage = "Helper 卸载失败：\(error.localizedDescription)"
                    self.lastError = error.localizedDescription
                }
                self.refreshHelperStatus()
                self.helperActionInProgress = false
            }
        }
    }

    func repairHelper() {
        helperActionInProgress = true
        helperActionMessage = "正在检查并修复 Helper..."
        Task.detached {
            let result = Result { try HelperInstallManager.repair() }
            await MainActor.run {
                switch result {
                case .success(let message):
                    self.helperActionMessage = message
                    UserDefaults.standard.set(true, forKey: self.initialHelperPromptKey)
                case .failure(let error):
                    self.helperActionMessage = "Helper 修复失败：\(error.localizedDescription)"
                    self.lastError = error.localizedDescription
                }
                self.refreshHelperStatus()
                self.helperActionInProgress = false
            }
        }
    }

    func dismissHelperOnboarding() {
        shouldShowHelperOnboarding = false
        UserDefaults.standard.set(true, forKey: initialHelperPromptKey)
    }

    func showHelperOnboarding() {
        shouldShowHelperOnboarding = true
    }

    private func evaluateInitialHelperPrompt() {
        guard !helperStatus.isUsable else {
            return
        }
        if helperStatus.needsUpdate {
            shouldShowHelperOnboarding = true
            return
        }
        guard !UserDefaults.standard.bool(forKey: initialHelperPromptKey) else { return }
        shouldShowHelperOnboarding = true
    }

    private func telemetryLoop() async {
        while !Task.isCancelled {
            let sample = await sampler.sample()
            if shouldIngest(sample) {
                ingest(sample)
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    private func safetyWatchdogLoop() async {
        while !Task.isCancelled {
            if phase == .running || phase == .starting {
                if let failure = await stressController.takeRuntimeFailure() {
                    liveSession?.log("压力引擎异常：\(failure)")
                    lastError = failure
                    stopStress(reason: .failed)
                } else {
                    evaluateDuration()
                    evaluateTelemetryWatchdog()
                }
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    private func shouldIngest(_ sample: TelemetrySample) -> Bool {
        guard let sequence = sample.helperSampleSequence else { return true }
        guard sequence != lastHelperSampleSequence else { return false }
        lastHelperSampleSequence = sequence
        return true
    }

    private func ingest(_ sample: TelemetrySample) {
        let now = systemUptime
        lastTelemetryArrivalUptime = now
        latestSample = sample
        updateHelperSamplingStatus(from: sample)
        bufferedSamples.append(sample)
        if bufferedSamples.count > liveSampleLimit {
            bufferedSamples.removeFirst(bufferedSamples.count - liveSampleLimit)
        }
        if publishesRealtimeSamples {
            objectWillChange.send()
            currentSample = sample
            liveSamples.append(sample)
            if liveSamples.count > liveSampleLimit {
                liveSamples.removeFirst(liveSamples.count - liveSampleLimit)
            }
        }

        let nextPermissionMessage: String
        if let message = sample.message, !message.isEmpty {
            nextPermissionMessage = message
        } else {
            nextPermissionMessage = sample.isDegraded ? sample.sourceDetail : "powermetrics 正常采样"
        }
        if permissionMessage != nextPermissionMessage {
            permissionMessage = nextPermissionMessage
        }

        if sample.source == .powermetrics,
           !sample.isDegraded,
           (sample.helperSampleAgeSeconds ?? 0) <= 2 {
            lastTrustedTelemetryUptime = now
            if phase == .running || phase == .starting {
                telemetryProtectionArmed = true
            }
        }

        guard phase == .running else { return }
        liveSession?.append(sample)
        evaluateSafety(sample)
        evaluateDuration()
    }

    private func evaluateDuration() {
        guard let liveSession,
              let stressStartedUptime,
              systemUptime - stressStartedUptime >= liveSession.configuration.durationSeconds else {
            return
        }
        stopStress(reason: .durationReached)
    }

    private func evaluateSafety(_ sample: TelemetrySample) {
        guard let configuration = liveSession?.configuration else { return }
        if configuration.stopOnCriticalThermalState, sample.thermalState == "Critical" {
            liveSession?.log("检测到 Critical 热状态，自动停止。")
            stopStress(reason: .thermalCritical)
            return
        }

        if sample.thermalState == "Serious" {
            if seriousThermalBeganUptime == nil {
                seriousThermalBeganUptime = systemUptime
                liveSession?.log("热状态进入 Serious，开始保护计时。")
            } else if systemUptime - (seriousThermalBeganUptime ?? systemUptime) >= configuration.thermalSeriousGraceSeconds {
                liveSession?.log("Serious 热状态持续超过 \(Int(configuration.thermalSeriousGraceSeconds)) 秒，自动停止。")
                stopStress(reason: .thermalSeriousTooLong)
                return
            }
        } else {
            seriousThermalBeganUptime = nil
        }

    }

    private func evaluateTelemetryWatchdog() {
        guard telemetryProtectionArmed else { return }
        let reference = lastTrustedTelemetryUptime ?? stressStartedUptime ?? systemUptime
        guard systemUptime - reference > 8 else { return }
        liveSession?.log("powermetrics 有效采样中断超过 8 秒，触发保护停止。")
        stopStress(reason: .telemetryLost)
    }

    private func finishStress(reason: StopReason) async {
        defer {
            finishTask = nil
        }
        await stressController.stop()
        seriousThermalBeganUptime = nil
        telemetryProtectionArmed = false
        stressStartedUptime = nil
        var finishedSession = liveSession
        finishedSession?.log("停止：\(reason.rawValue)。")

        let endedAt = Date()
        var fullCSVPath: String?
        var fullCSVRelativePath: String?
        var fullCSVSampleCount: Int?
        if let session = finishedSession {
            do {
                let csvURL = try store.saveFullSamplesCSV(for: session)
                fullCSVPath = csvURL.path
                fullCSVRelativePath = store.relativeCSVPath(for: csvURL)
                fullCSVSampleCount = session.samples.count
                finishedSession?.log("完整采样 CSV 已保存：\(csvURL.path)")
            } catch {
                finishedSession?.log("完整采样 CSV 保存失败：\(error.localizedDescription)")
                lastError = "完整采样 CSV 保存失败：\(error.localizedDescription)"
            }
        }

        if let summary = finishedSession?.makeSummary(
            stopReason: reason,
            endedAt: endedAt,
            fullSampleCSVPath: fullCSVPath,
            fullSampleCSVRelativePath: fullCSVRelativePath,
            fullSampleCSVSampleCount: fullCSVSampleCount
        ) {
            do {
                sessions = try store.appendSession(summary, to: sessions)
                selectedSessionID = summary.id
                if reason != .appExit {
                    completedReportSessionID = summary.id
                }
            } catch {
                lastError = "保存历史失败：\(error.localizedDescription)"
            }
        }
        liveSession = nil
        phase = .stopped
    }

    private var isCurrentTelemetryTrusted: Bool {
        guard let sample = latestSample,
              sample.source == .powermetrics,
              !sample.isDegraded,
              (sample.helperSampleAgeSeconds ?? 0) <= 2,
              let lastTelemetryArrivalUptime else {
            return false
        }
        return systemUptime - lastTelemetryArrivalUptime <= 2
    }

    private func updateHelperSamplingStatus(from sample: TelemetrySample) {
        guard let sequence = sample.helperSampleSequence else { return }
        var updated = helperStatus
        let nextState: String?
        if let age = sample.helperSampleAgeSeconds {
            nextState = age <= 2 ? "ready" : "restarting"
        } else if sequence == 0 {
            nextState = "starting"
        } else {
            nextState = nil
        }
        guard let nextState else { return }
        if nextState == helperStatus.samplingState {
            if nextState == "ready" { return }
            if let age = sample.helperSampleAgeSeconds,
               let previousAge = helperStatus.sampleAgeSeconds,
               Int(age) == Int(previousAge) {
                return
            }
        }
        updated.sampleAgeSeconds = sample.helperSampleAgeSeconds
        updated.samplingState = nextState
        if updated != helperStatus {
            helperStatus = updated
        }
    }

    private var systemUptime: TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }
}
