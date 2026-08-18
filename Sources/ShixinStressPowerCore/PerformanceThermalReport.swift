import Foundation

public enum StabilityAssessmentLevel: String, Codable, CaseIterable {
    case stable = "持续表现稳定"
    case slightRegression = "轻微回落"
    case possibleThermalLimit = "可能进入温控限制"
    case insufficientData = "采样不足，无法判断"

    public var symbolName: String {
        switch self {
        case .stable: "checkmark.seal.fill"
        case .slightRegression: "waveform.path.ecg"
        case .possibleThermalLimit: "thermometer.sun.fill"
        case .insufficientData: "questionmark.circle"
        }
    }
}

public struct StabilityAssessment: Codable, Equatable {
    public var level: StabilityAssessmentLevel
    public var explanation: String
    public var earlyWindowSeconds: TimeInterval?
    public var lateWindowSeconds: TimeInterval?
    public var powerDropPercent: Double?
    public var pFrequencyDropPercent: Double?
    public var gpuFrequencyDropPercent: Double?
    public var temperatureRiseC: Double?
    public var degradedSampleRatio: Double

    public init(
        level: StabilityAssessmentLevel,
        explanation: String,
        earlyWindowSeconds: TimeInterval?,
        lateWindowSeconds: TimeInterval?,
        powerDropPercent: Double?,
        pFrequencyDropPercent: Double?,
        gpuFrequencyDropPercent: Double?,
        temperatureRiseC: Double?,
        degradedSampleRatio: Double
    ) {
        self.level = level
        self.explanation = explanation
        self.earlyWindowSeconds = earlyWindowSeconds
        self.lateWindowSeconds = lateWindowSeconds
        self.powerDropPercent = powerDropPercent
        self.pFrequencyDropPercent = pFrequencyDropPercent
        self.gpuFrequencyDropPercent = gpuFrequencyDropPercent
        self.temperatureRiseC = temperatureRiseC
        self.degradedSampleRatio = degradedSampleRatio
    }
}

public struct PerformanceThermalReport: Codable, Equatable {
    public var reportSchemaVersion: Int?
    public var generatedAt: Date
    public var mode: StressMode
    public var startedAt: Date
    public var endedAt: Date
    public var durationSeconds: TimeInterval
    public var stopReason: StopReason
    public var peakPowerW: Double?
    public var sustainedPower60sW: Double?
    public var sustainedPower300sW: Double?
    public var estimatedEnergyWh: Double?
    public var peakCPUTemperatureC: Double?
    public var peakGPUTemperatureC: Double?
    public var peakSoCTemperatureC: Double?
    public var peakCompositeTemperatureC: Double?
    public var averageCPUTemperatureC: Double?
    public var averageGPUTemperatureC: Double?
    public var averageSoCTemperatureC: Double?
    public var averageCompositeTemperatureC: Double?
    public var peakFanRPM: Double?
    public var worstThermalState: String
    public var hasThrottlingHint: Bool
    public var throttlingHint: String
    public var samplingCompletenessPercent: Double
    public var sampleCount: Int
    public var degradedSampleCount: Int
    public var validSampleCount: Int?
    public var savedCurveSampleCount: Int
    public var fullSampleCSVSampleCount: Int?
    public var samplingGapCount: Int?
    public var largestSamplingGapSeconds: TimeInterval?
    public var coveredDurationSeconds: TimeInterval?
    public var timeCoveragePercent: Double?
    public var dataSourceSummary: String
    public var stability: StabilityAssessment

    public var validatedSustainedPower60sW: Double? {
        durationSeconds >= 60 * 0.95 ? sustainedPower60sW : nil
    }

    public var validatedSustainedPower300sW: Double? {
        durationSeconds >= 300 * 0.95 ? sustainedPower300sW : nil
    }
}

public enum PerformanceThermalReportBuilder {
    public static func makeReport(
        session: LiveSession,
        stopReason: StopReason,
        endedAt: Date,
        savedCurveSampleCount: Int,
        fullSampleCSVSampleCount: Int?
    ) -> PerformanceThermalReport {
        let sampleCount = session.samples.count
        let degradedSampleCount = session.samples.filter(\.isDegraded).count
        let validSampleCount = session.samples.filter {
            isModeRelevantSampleComplete($0, mode: session.configuration.mode)
        }.count
        let completeness = sampleCount == 0 ? 0 : Double(validSampleCount) / Double(sampleCount) * 100
        let timing = TelemetryCurveCompressor.timingSummary(samples: session.samples)
        let duration = max(0, endedAt.timeIntervalSince(session.startedAt))
        let timeCoverage = duration > 0 ? min(100, timing.coveredDurationSeconds / duration * 100) : 0
        let stability = assessStability(
            samples: session.samples,
            mode: session.configuration.mode,
            startedAt: session.startedAt,
            endedAt: endedAt,
            worstThermalState: session.worstThermalState
        )
        let relevantFrequencyDrop = relevantFrequencyDropPercent(stability: stability, mode: session.configuration.mode)
        let hasThrottlingHint = stability.level == .possibleThermalLimit && (relevantFrequencyDrop ?? 0) >= 10

        return PerformanceThermalReport(
            reportSchemaVersion: 3,
            generatedAt: Date(),
            mode: session.configuration.mode,
            startedAt: session.startedAt,
            endedAt: endedAt,
            durationSeconds: endedAt.timeIntervalSince(session.startedAt),
            stopReason: stopReason,
            peakPowerW: session.peakPowerW,
            sustainedPower60sW: session.sustainedPower60sW,
            sustainedPower300sW: session.sustainedPower300sW,
            estimatedEnergyWh: session.estimatedEnergyWh,
            peakCPUTemperatureC: session.peakCPUTemperatureC,
            peakGPUTemperatureC: session.peakGPUTemperatureC,
            peakSoCTemperatureC: session.peakSoCTemperatureC,
            peakCompositeTemperatureC: compositeTemperaturePeak(session.samples),
            averageCPUTemperatureC: timeWeightedAverage(samples: session.samples, value: \.cpuTemperatureC),
            averageGPUTemperatureC: timeWeightedAverage(samples: session.samples, value: \.gpuTemperatureC),
            averageSoCTemperatureC: timeWeightedAverage(samples: session.samples, value: \.socTemperatureC),
            averageCompositeTemperatureC: timeWeightedAverage(samples: session.samples, value: compositeTemperature),
            peakFanRPM: session.peakFanRPM,
            worstThermalState: session.worstThermalState,
            hasThrottlingHint: hasThrottlingHint,
            throttlingHint: throttlingHintText(for: stability.level),
            samplingCompletenessPercent: completeness,
            sampleCount: sampleCount,
            degradedSampleCount: degradedSampleCount,
            validSampleCount: validSampleCount,
            savedCurveSampleCount: savedCurveSampleCount,
            fullSampleCSVSampleCount: fullSampleCSVSampleCount,
            samplingGapCount: timing.gapIndexes.count,
            largestSamplingGapSeconds: timing.largestGapSeconds,
            coveredDurationSeconds: timing.coveredDurationSeconds,
            timeCoveragePercent: timeCoverage,
            dataSourceSummary: dataSourceSummary(samples: session.samples),
            stability: stability
        )
    }

    public static func assessStability(
        samples: [TelemetrySample],
        mode: StressMode,
        startedAt: Date,
        endedAt: Date,
        worstThermalState: String
    ) -> StabilityAssessment {
        let duration = endedAt.timeIntervalSince(startedAt)
        let degradedRatio = samples.isEmpty ? 0 : Double(samples.filter(\.isDegraded).count) / Double(samples.count)
        let comparableSamples = samples.filter { isModeRelevantSampleComplete($0, mode: mode) }
        guard duration >= 45, comparableSamples.count >= 15 else {
            return StabilityAssessment(
                level: .insufficientData,
                explanation: "测试时长或与当前模式相关的功耗、频率样本不足，无法可靠比较前段与后段趋势。",
                earlyWindowSeconds: nil,
                lateWindowSeconds: nil,
                powerDropPercent: nil,
                pFrequencyDropPercent: nil,
                gpuFrequencyDropPercent: nil,
                temperatureRiseC: nil,
                degradedSampleRatio: degradedRatio
            )
        }

        let earlyWindow = min(30, max(12, duration * 0.2))
        let lateWindow = min(60, max(20, duration * 0.4))
        let earlyEnd = startedAt.addingTimeInterval(earlyWindow)
        let lateStart = endedAt.addingTimeInterval(-lateWindow)
        let earlySamples = comparableSamples.filter { $0.capturedAt >= startedAt && $0.capturedAt <= earlyEnd }
        let lateSamples = comparableSamples.filter { $0.capturedAt >= lateStart && $0.capturedAt <= endedAt }

        guard earlySamples.count >= 5, lateSamples.count >= 5 else {
            return StabilityAssessment(
                level: .insufficientData,
                explanation: "前段或后段可比较样本不足，无法形成稳定趋势判断。",
                earlyWindowSeconds: earlyWindow,
                lateWindowSeconds: lateWindow,
                powerDropPercent: nil,
                pFrequencyDropPercent: nil,
                gpuFrequencyDropPercent: nil,
                temperatureRiseC: nil,
                degradedSampleRatio: degradedRatio
            )
        }

        let earlyPower = timeWeightedSummary(samples: earlySamples, value: { modeRelevantPower($0, mode: mode) })
        let latePower = timeWeightedSummary(samples: lateSamples, value: { modeRelevantPower($0, mode: mode) })
        let earlyPFrequency = timeWeightedSummary(samples: earlySamples, value: \.pClusterFrequencyMHz)
        let latePFrequency = timeWeightedSummary(samples: lateSamples, value: \.pClusterFrequencyMHz)
        let earlyGPUFrequency = timeWeightedSummary(samples: earlySamples, value: \.gpuFrequencyMHz)
        let lateGPUFrequency = timeWeightedSummary(samples: lateSamples, value: \.gpuFrequencyMHz)
        let minimumEarlyCoverage = earlyWindow * 0.6
        let minimumLateCoverage = lateWindow * 0.6
        let hasContinuousCoverage: Bool
        switch mode {
        case .cpu:
            hasContinuousCoverage = covers(earlyPower, seconds: minimumEarlyCoverage)
                && covers(latePower, seconds: minimumLateCoverage)
                && covers(earlyPFrequency, seconds: minimumEarlyCoverage)
                && covers(latePFrequency, seconds: minimumLateCoverage)
        case .gpu:
            hasContinuousCoverage = covers(earlyPower, seconds: minimumEarlyCoverage)
                && covers(latePower, seconds: minimumLateCoverage)
                && covers(earlyGPUFrequency, seconds: minimumEarlyCoverage)
                && covers(lateGPUFrequency, seconds: minimumLateCoverage)
        case .combined:
            hasContinuousCoverage = covers(earlyPower, seconds: minimumEarlyCoverage)
                && covers(latePower, seconds: minimumLateCoverage)
                && covers(earlyPFrequency, seconds: minimumEarlyCoverage)
                && covers(latePFrequency, seconds: minimumLateCoverage)
                && covers(earlyGPUFrequency, seconds: minimumEarlyCoverage)
                && covers(lateGPUFrequency, seconds: minimumLateCoverage)
        }
        guard hasContinuousCoverage else {
            return StabilityAssessment(
                level: .insufficientData,
                explanation: "前段或后段的连续采样覆盖不足，无法形成稳定趋势判断。",
                earlyWindowSeconds: earlyWindow,
                lateWindowSeconds: lateWindow,
                powerDropPercent: nil,
                pFrequencyDropPercent: nil,
                gpuFrequencyDropPercent: nil,
                temperatureRiseC: nil,
                degradedSampleRatio: degradedRatio
            )
        }

        let powerDrop = dropPercent(from: earlyPower?.value, to: latePower?.value)
        let pFrequencyDrop = dropPercent(from: earlyPFrequency?.value, to: latePFrequency?.value)
        let gpuFrequencyDrop = dropPercent(from: earlyGPUFrequency?.value, to: lateGPUFrequency?.value)
        let earlyTemperature = timeWeightedAverage(samples: earlySamples, value: compositeTemperature)
        let lateTemperature = timeWeightedAverage(samples: lateSamples, value: compositeTemperature)
        let temperatureRise = zipOptionals(earlyTemperature, lateTemperature).map { $0.1 - $0.0 }
        let relevantDrops: [Double?]
        let relevantFrequencyDrop: Double?
        switch mode {
        case .cpu:
            relevantDrops = [powerDrop, pFrequencyDrop]
            relevantFrequencyDrop = pFrequencyDrop
        case .gpu:
            relevantDrops = [powerDrop, gpuFrequencyDrop]
            relevantFrequencyDrop = gpuFrequencyDrop
        case .combined:
            relevantDrops = [powerDrop, pFrequencyDrop, gpuFrequencyDrop]
            relevantFrequencyDrop = [pFrequencyDrop, gpuFrequencyDrop].compactMap { $0 }.max()
        }
        let strongestDrop = relevantDrops.compactMap { $0 }.max() ?? 0
        let severeThermalState = thermalRank(worstThermalState) >= thermalRank("Serious")
        let thermalStress = (temperatureRise ?? 0) >= 8 || severeThermalState

        let level: StabilityAssessmentLevel
        let explanation: String
        if degradedRatio >= 0.2 {
            level = .insufficientData
            explanation = "降级样本比例过高，当前数据不足以形成可靠的持续性能判断。"
        } else if (relevantFrequencyDrop ?? 0) >= 15, thermalStress {
            level = .possibleThermalLimit
            explanation = "后段相关核心频率明显下降，同时伴随温度上升或系统热状态升高，趋势上可能进入温控限制。"
        } else if severeThermalState, (relevantFrequencyDrop ?? 0) >= 10 {
            level = .possibleThermalLimit
            explanation = "测试期间出现 Serious/Critical 热状态，并伴随相关核心频率回落，建议结合完整 CSV 复核。"
        } else if strongestDrop >= 10 {
            level = .slightRegression
            explanation = "后段相关功耗或频率有一定回落，但没有形成明确的温控限制证据。"
        } else {
            level = .stable
            explanation = "前段与后段相关功耗、频率和热状态变化较小，本次趋势显示持续释放较稳定。"
        }

        return StabilityAssessment(
            level: level,
            explanation: explanation,
            earlyWindowSeconds: earlyWindow,
            lateWindowSeconds: lateWindow,
            powerDropPercent: powerDrop,
            pFrequencyDropPercent: pFrequencyDrop,
            gpuFrequencyDropPercent: gpuFrequencyDrop,
            temperatureRiseC: temperatureRise,
            degradedSampleRatio: degradedRatio
        )
    }

    private static func throttlingHintText(for level: StabilityAssessmentLevel) -> String {
        switch level {
        case .stable:
            return "未发现明显降频迹象"
        case .slightRegression:
            return "存在轻微性能回落，未形成明确频率限制证据"
        case .possibleThermalLimit:
            return "可能存在温控限制迹象"
        case .insufficientData:
            return "采样不足，暂不判断"
        }
    }

    private static func dataSourceSummary(samples: [TelemetrySample]) -> String {
        guard !samples.isEmpty else { return "没有采样数据" }
        let powerSamples = samples.filter { $0.source == .powermetrics }.count
        let fallbackSamples = samples.count - powerSamples
        let temperatureSamples = samples.filter {
            $0.cpuTemperatureC != nil || $0.gpuTemperatureC != nil || $0.socTemperatureC != nil
        }.count
        let fanSamples = samples.filter { $0.fanRPMs?.isEmpty == false }.count
        return "powermetrics \(powerSamples) / fallback \(fallbackSamples) · 温度 \(temperatureSamples) · 风扇 \(fanSamples)"
    }

    private static func isModeRelevantSampleComplete(_ sample: TelemetrySample, mode: StressMode) -> Bool {
        guard sample.source == .powermetrics,
              !sample.isDegraded,
              sample.totalDisplayedPowerW != nil else {
            return false
        }
        switch mode {
        case .cpu:
            return sample.cpuPowerW != nil && (sample.pClusterFrequencyMHz != nil || sample.eClusterFrequencyMHz != nil)
        case .gpu:
            return sample.gpuPowerW != nil && sample.gpuFrequencyMHz != nil
        case .combined:
            return sample.cpuPowerW != nil
                && sample.gpuPowerW != nil
                && (sample.pClusterFrequencyMHz != nil || sample.eClusterFrequencyMHz != nil)
                && sample.gpuFrequencyMHz != nil
        }
    }

    private static func relevantFrequencyDropPercent(stability: StabilityAssessment, mode: StressMode) -> Double? {
        switch mode {
        case .cpu:
            return stability.pFrequencyDropPercent
        case .gpu:
            return stability.gpuFrequencyDropPercent
        case .combined:
            return [stability.pFrequencyDropPercent, stability.gpuFrequencyDropPercent]
                .compactMap { $0 }
                .max()
        }
    }

    private static func modeRelevantPower(_ sample: TelemetrySample, mode: StressMode) -> Double? {
        switch mode {
        case .cpu:
            return sample.cpuPowerW
        case .gpu:
            return sample.gpuPowerW
        case .combined:
            return sample.totalDisplayedPowerW
        }
    }

    private static func compositeTemperaturePeak(_ samples: [TelemetrySample]) -> Double? {
        samples.compactMap { sample in
            [sample.cpuTemperatureC, sample.gpuTemperatureC, sample.socTemperatureC].compactMap { $0 }.max()
        }.max()
    }

    private static func compositeTemperature(_ sample: TelemetrySample) -> Double? {
        [sample.cpuTemperatureC, sample.gpuTemperatureC, sample.socTemperatureC]
            .compactMap { $0 }
            .max()
    }

    private static func timeWeightedAverage(
        samples: [TelemetrySample],
        value: (TelemetrySample) -> Double?
    ) -> Double? {
        timeWeightedSummary(samples: samples, value: value)?.value
    }

    private static func timeWeightedSummary(
        samples: [TelemetrySample],
        value: (TelemetrySample) -> Double?
    ) -> (value: Double, coveredDuration: TimeInterval)? {
        let points = samples.compactMap { sample -> (Date, Double)? in
            guard let number = value(sample), number.isFinite else { return nil }
            return (sample.capturedAt, number)
        }
        .sorted { $0.0 < $1.0 }
        guard points.count >= 2 else {
            return points.first.map { (value: $0.1, coveredDuration: 0) }
        }
        let timing = TelemetryCurveCompressor.timingSummary(samples: samples)
        var weightedValue = 0.0
        var coveredDuration = 0.0
        for index in 1..<points.count {
            let duration = points[index].0.timeIntervalSince(points[index - 1].0)
            guard duration > 0, duration <= timing.trustedGapThresholdSeconds else { continue }
            weightedValue += (points[index - 1].1 + points[index].1) / 2 * duration
            coveredDuration += duration
        }
        guard coveredDuration > 0 else { return nil }
        return (weightedValue / coveredDuration, coveredDuration)
    }

    private static func covers(
        _ summary: (value: Double, coveredDuration: TimeInterval)?,
        seconds: TimeInterval
    ) -> Bool {
        guard let summary else { return false }
        return summary.coveredDuration >= seconds
    }

    private static func dropPercent(from early: Double?, to late: Double?) -> Double? {
        guard let early, let late, early.isFinite, late.isFinite, early > 0 else { return nil }
        return max(0, (early - late) / early * 100)
    }

    private static func thermalRank(_ state: String) -> Int {
        switch state {
        case "Nominal": 0
        case "Fair": 1
        case "Serious": 2
        case "Critical": 3
        default: -1
        }
    }

    private static func zipOptionals<T, U>(_ lhs: T?, _ rhs: U?) -> (T, U)? {
        guard let lhs, let rhs else { return nil }
        return (lhs, rhs)
    }
}
