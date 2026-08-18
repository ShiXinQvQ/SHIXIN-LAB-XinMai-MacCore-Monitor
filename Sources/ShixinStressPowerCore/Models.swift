// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum StressMode: String, CaseIterable, Identifiable, Codable {
    case cpu = "CPU"
    case gpu = "GPU"
    case combined = "CPU + GPU"

    public var id: String { rawValue }

    public var title: String { rawValue }

    public var systemImage: String {
        switch self {
        case .cpu: "cpu"
        case .gpu: "rectangle.3.group"
        case .combined: "flame.fill"
        }
    }
}

public enum StressPhase: String, Codable {
    case idle = "待机"
    case starting = "启动中"
    case running = "运行中"
    case stopping = "停止中"
    case stopped = "已停止"
    case failed = "失败"
}

public enum TelemetrySource: String, Codable {
    case powermetrics = "powermetrics"
    case fallback = "thermalState fallback"
}

public enum StopReason: String, Codable {
    case user = "用户手动停止"
    case durationReached = "达到设定时长"
    case thermalCritical = "系统热状态 Critical"
    case thermalSeriousTooLong = "系统热状态 Serious 持续过久"
    case telemetryLost = "采样中断保护"
    case failed = "压力测试异常"
    case appExit = "App 退出清理"
}

public struct StressConfiguration: Codable, Equatable {
    public var mode: StressMode
    public var durationSeconds: TimeInterval
    public var cpuWorkers: Int
    public var gpuWorkItems: Int
    public var gpuIterations: Int
    public var thermalSeriousGraceSeconds: TimeInterval
    public var stopOnCriticalThermalState: Bool

    public init(
        mode: StressMode,
        durationSeconds: TimeInterval,
        cpuWorkers: Int,
        gpuWorkItems: Int,
        gpuIterations: Int,
        thermalSeriousGraceSeconds: TimeInterval,
        stopOnCriticalThermalState: Bool
    ) {
        self.mode = mode
        self.durationSeconds = durationSeconds
        self.cpuWorkers = cpuWorkers
        self.gpuWorkItems = gpuWorkItems
        self.gpuIterations = gpuIterations
        self.thermalSeriousGraceSeconds = thermalSeriousGraceSeconds
        self.stopOnCriticalThermalState = stopOnCriticalThermalState
    }

    public static func `default`(logicalCPUs: Int) -> StressConfiguration {
        StressConfiguration(
            mode: .combined,
            durationSeconds: 300,
            cpuWorkers: max(1, logicalCPUs),
            gpuWorkItems: 1_048_576,
            gpuIterations: 2048,
            thermalSeriousGraceSeconds: 120,
            stopOnCriticalThermalState: true
        )
    }
}

public struct TelemetrySample: Identifiable, Codable {
    public var id: UUID
    public var capturedAt: Date
    public var source: TelemetrySource
    public var sourceDetail: String
    public var thermalState: String
    public var thermalPressure: String?
    public var cpuPowerW: Double?
    public var gpuPowerW: Double?
    public var anePowerW: Double?
    public var packagePowerW: Double?
    public var cpuActivePercent: Double?
    public var gpuActivePercent: Double?
    public var eClusterFrequencyMHz: Double?
    public var pClusterFrequencyMHz: Double?
    public var gpuFrequencyMHz: Double?
    public var cpuTemperatureC: Double?
    public var gpuTemperatureC: Double?
    public var socTemperatureC: Double?
    public var powerSource: PowerSourceSnapshot
    public var isDegraded: Bool
    public var message: String?
    public var temperatureSourceDetail: String?
    public var cpuTemperatureSensorCount: Int?
    public var gpuTemperatureSensorCount: Int?
    public var socTemperatureSensorCount: Int?
    public var fanRPMs: [Double]?
    public var ssdTemperatureC: Double?
    public var diskTemperatureC: Double?
    public var diskTemperatureSourceDetail: String?
    public var wifiTemperatureC: Double?
    public var airflowTemperatureC: Double?
    public var ambientTemperatureC: Double?
    public var helperSampleSequence: UInt64?
    public var helperSampleAgeSeconds: Double?
    public var samplingIntervalMilliseconds: Int?

    public init(
        id: UUID = UUID(),
        capturedAt: Date,
        source: TelemetrySource,
        sourceDetail: String,
        thermalState: String,
        thermalPressure: String?,
        cpuPowerW: Double?,
        gpuPowerW: Double?,
        anePowerW: Double?,
        packagePowerW: Double?,
        cpuActivePercent: Double?,
        gpuActivePercent: Double?,
        eClusterFrequencyMHz: Double?,
        pClusterFrequencyMHz: Double?,
        gpuFrequencyMHz: Double?,
        cpuTemperatureC: Double?,
        gpuTemperatureC: Double?,
        socTemperatureC: Double? = nil,
        powerSource: PowerSourceSnapshot,
        isDegraded: Bool,
        message: String?,
        temperatureSourceDetail: String? = nil,
        cpuTemperatureSensorCount: Int? = nil,
        gpuTemperatureSensorCount: Int? = nil,
        socTemperatureSensorCount: Int? = nil,
        fanRPMs: [Double]? = nil,
        ssdTemperatureC: Double? = nil,
        diskTemperatureC: Double? = nil,
        diskTemperatureSourceDetail: String? = nil,
        wifiTemperatureC: Double? = nil,
        airflowTemperatureC: Double? = nil,
        ambientTemperatureC: Double? = nil,
        helperSampleSequence: UInt64? = nil,
        helperSampleAgeSeconds: Double? = nil,
        samplingIntervalMilliseconds: Int? = nil
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.source = source
        self.sourceDetail = sourceDetail
        self.thermalState = thermalState
        self.thermalPressure = thermalPressure
        self.cpuPowerW = cpuPowerW
        self.gpuPowerW = gpuPowerW
        self.anePowerW = anePowerW
        self.packagePowerW = packagePowerW
        self.cpuActivePercent = cpuActivePercent
        self.gpuActivePercent = gpuActivePercent
        self.eClusterFrequencyMHz = eClusterFrequencyMHz
        self.pClusterFrequencyMHz = pClusterFrequencyMHz
        self.gpuFrequencyMHz = gpuFrequencyMHz
        self.cpuTemperatureC = cpuTemperatureC
        self.gpuTemperatureC = gpuTemperatureC
        self.socTemperatureC = socTemperatureC
        self.powerSource = powerSource
        self.isDegraded = isDegraded
        self.message = message
        self.temperatureSourceDetail = temperatureSourceDetail
        self.cpuTemperatureSensorCount = cpuTemperatureSensorCount
        self.gpuTemperatureSensorCount = gpuTemperatureSensorCount
        self.socTemperatureSensorCount = socTemperatureSensorCount
        self.fanRPMs = fanRPMs
        self.ssdTemperatureC = ssdTemperatureC
        self.diskTemperatureC = diskTemperatureC
        self.diskTemperatureSourceDetail = diskTemperatureSourceDetail
        self.wifiTemperatureC = wifiTemperatureC
        self.airflowTemperatureC = airflowTemperatureC
        self.ambientTemperatureC = ambientTemperatureC
        self.helperSampleSequence = helperSampleSequence
        self.helperSampleAgeSeconds = helperSampleAgeSeconds
        self.samplingIntervalMilliseconds = samplingIntervalMilliseconds
    }

    public var totalDisplayedPowerW: Double? {
        if let packagePowerW { return packagePowerW }
        let parts = [cpuPowerW, gpuPowerW, anePowerW].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0, +)
    }

    public var primaryFanRPM: Double? {
        fanRPMs?.filter { $0.isFinite }.max()
    }
}

public struct PowerSourceSnapshot: Codable {
    public var source: String
    public var batteryPercent: Int?
    public var isCharging: Bool?
    public var adapterWatts: Int?

    public init(source: String, batteryPercent: Int?, isCharging: Bool?, adapterWatts: Int?) {
        self.source = source
        self.batteryPercent = batteryPercent
        self.isCharging = isCharging
        self.adapterWatts = adapterWatts
    }

    public static let unknown = PowerSourceSnapshot(source: "未知", batteryPercent: nil, isCharging: nil, adapterWatts: nil)
}

public struct SessionEnvironmentSnapshot: Codable, Equatable {
    public var capturedAt: Date
    public var modelName: String?
    public var modelIdentifier: String?
    public var soc: String?
    public var cpuCores: String?
    public var gpuCores: String?
    public var systemMemory: String?
    public var systemVersion: String?
    public var kernelVersion: String?

    public init?(
        hardwareProfile: HardwareProfile
    ) {
        let modelName = Self.value("型号名称", in: hardwareProfile)
        let modelIdentifier = Self.value("型号标识符", in: hardwareProfile)
        let soc = Self.value("SoC", in: hardwareProfile)
        let cpuCores = Self.value("CPU 内核", in: hardwareProfile)
        let gpuCores = Self.value("GPU 内核", in: hardwareProfile)
        let systemMemory = Self.value("系统内存", in: hardwareProfile)
        let systemVersion = Self.value("系统版本", in: hardwareProfile)
        let kernelVersion = Self.value("内核版本", in: hardwareProfile)
        let values = [modelName, modelIdentifier, soc, cpuCores, gpuCores, systemMemory, systemVersion, kernelVersion]
            .compactMap { $0 }
            .filter { !$0.isEmpty && $0 != "读取中" && $0 != "未知" }
        guard !values.isEmpty else { return nil }

        self.capturedAt = hardwareProfile.generatedAt
        self.modelName = modelName
        self.modelIdentifier = modelIdentifier
        self.soc = soc
        self.cpuCores = cpuCores
        self.gpuCores = gpuCores
        self.systemMemory = systemMemory
        self.systemVersion = systemVersion
        self.kernelVersion = kernelVersion
    }

    public init(
        capturedAt: Date,
        modelName: String?,
        modelIdentifier: String?,
        soc: String?,
        cpuCores: String?,
        gpuCores: String?,
        systemMemory: String?,
        systemVersion: String?,
        kernelVersion: String?
    ) {
        self.capturedAt = capturedAt
        self.modelName = modelName
        self.modelIdentifier = modelIdentifier
        self.soc = soc
        self.cpuCores = cpuCores
        self.gpuCores = gpuCores
        self.systemMemory = systemMemory
        self.systemVersion = systemVersion
        self.kernelVersion = kernelVersion
    }

    private static func value(_ title: String, in profile: HardwareProfile) -> String? {
        if let value = profile.headlineRows.first(where: { $0.title == title })?.value {
            return value
        }
        for section in profile.sections {
            if let value = section.rows.first(where: { $0.title == title })?.value {
                return value
            }
        }
        return nil
    }
}

public struct TelemetrySamplingGap: Codable, Equatable {
    public var startedAt: Date
    public var endedAt: Date

    public init(startedAt: Date, endedAt: Date) {
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

public struct TelemetryCurveArchiveMetadata: Codable, Equatable {
    public var strategyVersion: Int
    public var originalSampleCount: Int
    public var savedSampleCount: Int
    public var expectedIntervalSeconds: TimeInterval?
    public var coveredDurationSeconds: TimeInterval
    public var samplingGapCount: Int
    public var largestSamplingGapSeconds: TimeInterval?
    public var samplingGaps: [TelemetrySamplingGap]?

    public init(
        strategyVersion: Int,
        originalSampleCount: Int,
        savedSampleCount: Int,
        expectedIntervalSeconds: TimeInterval?,
        coveredDurationSeconds: TimeInterval,
        samplingGapCount: Int,
        largestSamplingGapSeconds: TimeInterval?,
        samplingGaps: [TelemetrySamplingGap]? = nil
    ) {
        self.strategyVersion = strategyVersion
        self.originalSampleCount = originalSampleCount
        self.savedSampleCount = savedSampleCount
        self.expectedIntervalSeconds = expectedIntervalSeconds
        self.coveredDurationSeconds = coveredDurationSeconds
        self.samplingGapCount = samplingGapCount
        self.largestSamplingGapSeconds = largestSamplingGapSeconds
        self.samplingGaps = samplingGaps
    }
}

public struct StressSessionSummary: Identifiable, Codable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var configuration: StressConfiguration
    public var stopReason: StopReason
    public var durationSeconds: TimeInterval
    public var peakPowerW: Double?
    public var sustainedPower60sW: Double?
    public var sustainedPower300sW: Double?
    public var estimatedEnergyWh: Double?
    public var peakCPUPowerW: Double?
    public var peakGPUPowerW: Double?
    public var peakCPUTemperatureC: Double?
    public var peakGPUTemperatureC: Double?
    public var peakSoCTemperatureC: Double?
    public var peakFanRPM: Double?
    public var worstThermalState: String
    public var sampleCount: Int
    public var degradedSampleCount: Int
    public var savedCurveSampleCount: Int?
    public var fullSampleCSVPath: String?
    public var fullSampleCSVRelativePath: String?
    public var fullSampleCSVSampleCount: Int?
    public var sessionSchemaVersion: Int?
    public var environmentSnapshot: SessionEnvironmentSnapshot?
    public var curveArchiveMetadata: TelemetryCurveArchiveMetadata?
    public var performanceReport: PerformanceThermalReport?
    public var logMessages: [String]
    public var samples: [TelemetrySample]

    public var validatedSustainedPower60sW: Double? {
        durationSeconds >= 60 * 0.95 ? sustainedPower60sW : nil
    }

    public var validatedSustainedPower300sW: Double? {
        durationSeconds >= 300 * 0.95 ? sustainedPower300sW : nil
    }
}

public struct LiveSession: Identifiable {
    public var id = UUID()
    public var startedAt = Date()
    public var configuration: StressConfiguration
    public var samples: [TelemetrySample] = []
    public var logMessages: [String] = []
    public var stopReason: StopReason?
    public var environmentSnapshot: SessionEnvironmentSnapshot?

    public init(configuration: StressConfiguration, environmentSnapshot: SessionEnvironmentSnapshot? = nil) {
        self.configuration = configuration
        self.environmentSnapshot = environmentSnapshot
    }

    public var elapsedSeconds: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }

    public var peakPowerW: Double? {
        samples.compactMap(\.totalDisplayedPowerW).max()
    }

    public var peakCPUPowerW: Double? {
        samples.compactMap(\.cpuPowerW).max()
    }

    public var peakGPUPowerW: Double? {
        samples.compactMap(\.gpuPowerW).max()
    }

    public var peakCPUTemperatureC: Double? {
        samples.compactMap(\.cpuTemperatureC).max()
    }

    public var peakGPUTemperatureC: Double? {
        samples.compactMap(\.gpuTemperatureC).max()
    }

    public var peakSoCTemperatureC: Double? {
        samples.compactMap(\.socTemperatureC).max()
    }

    public var peakFanRPM: Double? {
        samples.compactMap(\.primaryFanRPM).max()
    }

    public var sustainedPower60sW: Double? {
        rollingAveragePower(windowSeconds: 60)
    }

    public var sustainedPower300sW: Double? {
        rollingAveragePower(windowSeconds: 300)
    }

    public var estimatedEnergyWh: Double? {
        let points = powerPoints
        guard let first = points.first?.date,
              let last = points.last?.date,
              last > first else {
            return nil
        }
        let result = integratePower(points: points, from: first, to: last)
        let span = last.timeIntervalSince(first)
        guard result.coveredSeconds >= span * 0.9 else { return nil }
        return result.joules / 3600
    }

    public var worstThermalState: String {
        let order = ["Nominal": 0, "Fair": 1, "Serious": 2, "Critical": 3]
        return samples
            .map(\.thermalState)
            .max { (order[$0] ?? -1) < (order[$1] ?? -1) } ?? "Unknown"
    }

    public mutating func append(_ sample: TelemetrySample, maxSamples: Int = 20_000) {
        samples.append(sample)
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
    }

    public mutating func log(_ message: String) {
        let stamp = Formatters.logDate(Date())
        logMessages.insert("[\(stamp)] \(message)", at: 0)
        if logMessages.count > 200 {
            logMessages.removeLast(logMessages.count - 200)
        }
    }

    public func makeSummary(
        stopReason: StopReason,
        endedAt: Date = Date(),
        fullSampleCSVPath: String? = nil,
        fullSampleCSVRelativePath: String? = nil,
        fullSampleCSVSampleCount: Int? = nil
    ) -> StressSessionSummary {
        let curveArchive = TelemetryCurveCompressor.archive(
            samples: samples,
            maxSamples: 900,
            mode: configuration.mode
        )
        let savedCurveSamples = curveArchive.samples
        let report = PerformanceThermalReportBuilder.makeReport(
            session: self,
            stopReason: stopReason,
            endedAt: endedAt,
            savedCurveSampleCount: savedCurveSamples.count,
            fullSampleCSVSampleCount: fullSampleCSVSampleCount
        )
        return StressSessionSummary(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            configuration: configuration,
            stopReason: stopReason,
            durationSeconds: endedAt.timeIntervalSince(startedAt),
            peakPowerW: peakPowerW,
            sustainedPower60sW: sustainedPower60sW,
            sustainedPower300sW: sustainedPower300sW,
            estimatedEnergyWh: estimatedEnergyWh,
            peakCPUPowerW: peakCPUPowerW,
            peakGPUPowerW: peakGPUPowerW,
            peakCPUTemperatureC: peakCPUTemperatureC,
            peakGPUTemperatureC: peakGPUTemperatureC,
            peakSoCTemperatureC: peakSoCTemperatureC,
            peakFanRPM: peakFanRPM,
            worstThermalState: worstThermalState,
            sampleCount: samples.count,
            degradedSampleCount: samples.filter(\.isDegraded).count,
            savedCurveSampleCount: savedCurveSamples.count,
            fullSampleCSVPath: fullSampleCSVPath,
            fullSampleCSVRelativePath: fullSampleCSVRelativePath,
            fullSampleCSVSampleCount: fullSampleCSVSampleCount,
            sessionSchemaVersion: 3,
            environmentSnapshot: environmentSnapshot,
            curveArchiveMetadata: curveArchive.metadata,
            performanceReport: report,
            logMessages: logMessages,
            samples: savedCurveSamples
        )
    }

    private func rollingAveragePower(windowSeconds: TimeInterval) -> Double? {
        let points = powerPoints
        guard let first = points.first?.date,
              let latest = points.last?.date,
              latest.timeIntervalSince(first) >= windowSeconds * 0.95 else {
            return nil
        }
        let windowStart = latest.addingTimeInterval(-windowSeconds)
        let result = integratePower(points: points, from: windowStart, to: latest)
        guard result.coveredSeconds >= windowSeconds * 0.95 else { return nil }
        return result.joules / result.coveredSeconds
    }

    private var powerPoints: [(date: Date, watts: Double)] {
        samples.compactMap { sample in
            guard let power = sample.totalDisplayedPowerW,
                  power.isFinite,
                  power >= 0 else {
                return nil
            }
            return (sample.capturedAt, power)
        }
        .sorted { $0.date < $1.date }
    }

    private func integratePower(
        points: [(date: Date, watts: Double)],
        from rangeStart: Date,
        to rangeEnd: Date
    ) -> (joules: Double, coveredSeconds: TimeInterval) {
        guard points.count >= 2, rangeEnd > rangeStart else { return (0, 0) }
        let maximumGap = maximumTrustedPowerGap(points: points)
        var joules = 0.0
        var coveredSeconds = 0.0

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let fullDuration = current.date.timeIntervalSince(previous.date)
            guard fullDuration > 0, fullDuration <= maximumGap else { continue }

            let segmentStart = max(previous.date, rangeStart)
            let segmentEnd = min(current.date, rangeEnd)
            let duration = segmentEnd.timeIntervalSince(segmentStart)
            guard duration > 0 else { continue }

            let startRatio = segmentStart.timeIntervalSince(previous.date) / fullDuration
            let endRatio = segmentEnd.timeIntervalSince(previous.date) / fullDuration
            let startPower = previous.watts + (current.watts - previous.watts) * startRatio
            let endPower = previous.watts + (current.watts - previous.watts) * endRatio
            joules += (startPower + endPower) / 2 * duration
            coveredSeconds += duration
        }

        return (joules, coveredSeconds)
    }

    private func maximumTrustedPowerGap(points: [(date: Date, watts: Double)]) -> TimeInterval {
        let intervals = zip(points, points.dropFirst())
            .map { $1.date.timeIntervalSince($0.date) }
            .filter { $0 > 0 && $0.isFinite }
            .sorted()
        guard !intervals.isEmpty else { return 2 }
        let median = intervals[intervals.count / 2]
        return min(5, max(2, median * 4))
    }
}
