import Foundation

public enum TelemetryCurveCompressor {
    public struct ArchiveResult {
        public var samples: [TelemetrySample]
        public var metadata: TelemetryCurveArchiveMetadata

        public init(samples: [TelemetrySample], metadata: TelemetryCurveArchiveMetadata) {
            self.samples = samples
            self.metadata = metadata
        }
    }

    public static func archive(
        samples: [TelemetrySample],
        maxSamples: Int,
        mode: StressMode
    ) -> ArchiveResult {
        let sorted = samples.sorted { lhs, rhs in
            if lhs.capturedAt == rhs.capturedAt { return lhs.id.uuidString < rhs.id.uuidString }
            return lhs.capturedAt < rhs.capturedAt
        }
        let timing = timingSummary(samples: sorted)
        let limit = max(2, maxSamples)
        let archived = sorted.count <= limit
            ? sorted
            : compressedSamples(sorted, maxSamples: limit, mode: mode, timing: timing)
        let gaps = timing.gapIndexes.compactMap { gapIndex -> TelemetrySamplingGap? in
            guard gapIndex > 0, gapIndex < sorted.count else { return nil }
            return TelemetrySamplingGap(
                startedAt: sorted[gapIndex - 1].capturedAt,
                endedAt: sorted[gapIndex].capturedAt
            )
        }
        let metadata = TelemetryCurveArchiveMetadata(
            strategyVersion: 1,
            originalSampleCount: sorted.count,
            savedSampleCount: archived.count,
            expectedIntervalSeconds: timing.expectedIntervalSeconds,
            coveredDurationSeconds: timing.coveredDurationSeconds,
            samplingGapCount: timing.gapIndexes.count,
            largestSamplingGapSeconds: timing.largestGapSeconds,
            samplingGaps: gaps
        )
        return ArchiveResult(samples: archived, metadata: metadata)
    }

    public static func timingSummary(samples: [TelemetrySample]) -> (
        expectedIntervalSeconds: TimeInterval?,
        trustedGapThresholdSeconds: TimeInterval,
        coveredDurationSeconds: TimeInterval,
        gapIndexes: [Int],
        largestGapSeconds: TimeInterval?
    ) {
        guard samples.count >= 2 else {
            return (nil, 2, 0, [], nil)
        }
        let sorted = samples.sorted { $0.capturedAt < $1.capturedAt }
        let intervals = zip(sorted, sorted.dropFirst())
            .map { $1.capturedAt.timeIntervalSince($0.capturedAt) }
        let validIntervals = intervals.filter { $0 > 0 && $0.isFinite }.sorted()
        guard !validIntervals.isEmpty else {
            return (nil, 2, 0, [], nil)
        }
        let median = validIntervals[validIntervals.count / 2]
        let threshold = min(10, max(2, median * 4))
        var coveredDuration = 0.0
        var gapIndexes: [Int] = []
        var largestGap: TimeInterval?
        for (offset, interval) in intervals.enumerated() where interval > 0 && interval.isFinite {
            if interval <= threshold {
                coveredDuration += interval
            } else {
                gapIndexes.append(offset + 1)
                largestGap = max(largestGap ?? 0, interval)
            }
        }
        return (median, threshold, coveredDuration, gapIndexes, largestGap)
    }

    private static func compressedSamples(
        _ samples: [TelemetrySample],
        maxSamples: Int,
        mode: StressMode,
        timing: (
            expectedIntervalSeconds: TimeInterval?,
            trustedGapThresholdSeconds: TimeInterval,
            coveredDurationSeconds: TimeInterval,
            gapIndexes: [Int],
            largestGapSeconds: TimeInterval?
        )
    ) -> [TelemetrySample] {
        guard samples.count > maxSamples else { return samples }
        var selected = Set<Int>([0, samples.count - 1])

        let globalValueReaders: [(TelemetrySample) -> Double?] = [
            { $0.totalDisplayedPowerW },
            { $0.cpuPowerW },
            { $0.gpuPowerW },
            { compositeTemperature($0) },
            { $0.pClusterFrequencyMHz },
            { $0.gpuFrequencyMHz },
            { $0.primaryFanRPM }
        ]
        var globalExtrema: [Int] = []
        for reader in globalValueReaders {
            appendExtrema(in: 0..<samples.count, samples: samples, value: reader, to: &globalExtrema)
        }
        addEvenly(globalExtrema, capacity: maxSamples - selected.count, to: &selected)

        var eventIndexes: [Int] = []
        for index in 1..<samples.count {
            let previous = samples[index - 1]
            let current = samples[index]
            if previous.thermalState != current.thermalState
                || previous.isDegraded != current.isDegraded
                || previous.source != current.source {
                eventIndexes.append(index - 1)
                eventIndexes.append(index)
            }
        }
        for gapIndex in timing.gapIndexes {
            eventIndexes.append(max(0, gapIndex - 1))
            eventIndexes.append(min(samples.count - 1, gapIndex))
        }
        addEvenly(eventIndexes, capacity: maxSamples - selected.count, to: &selected)

        let remainingForBuckets = max(0, maxSamples - selected.count)
        if remainingForBuckets > 0 {
            let candidatesPerBucket = 7
            let bucketCount = max(1, remainingForBuckets / candidatesPerBucket)
            let start = samples.first?.capturedAt.timeIntervalSinceReferenceDate ?? 0
            let end = samples.last?.capturedAt.timeIntervalSinceReferenceDate ?? start
            let duration = max(0.001, end - start)
            var bucketCandidates: [Int] = []

            for bucket in 0..<bucketCount {
                let lowerTime = start + duration * Double(bucket) / Double(bucketCount)
                let upperTime = start + duration * Double(bucket + 1) / Double(bucketCount)
                let lowerIndex = lowerBound(samples, timestamp: lowerTime)
                let upperIndex = bucket == bucketCount - 1
                    ? samples.count
                    : lowerBound(samples, timestamp: upperTime)
                guard lowerIndex < upperIndex else { continue }
                let range = lowerIndex..<upperIndex
                bucketCandidates.append(closestIndex(to: (lowerTime + upperTime) / 2, in: range, samples: samples))
                appendExtrema(in: range, samples: samples, value: { $0.totalDisplayedPowerW }, to: &bucketCandidates)
                appendExtrema(in: range, samples: samples, value: { compositeTemperature($0) }, to: &bucketCandidates)
                appendExtrema(in: range, samples: samples, value: { relevantFrequency($0, mode: mode) }, to: &bucketCandidates)
            }
            addEvenly(bucketCandidates, capacity: maxSamples - selected.count, to: &selected)
        }

        if selected.count < maxSamples {
            let fill = evenlySpacedIndexes(count: samples.count, targetCount: maxSamples)
            addEvenly(fill, capacity: maxSamples - selected.count, to: &selected)
        }

        return selected.sorted().prefix(maxSamples).map { samples[$0] }
    }

    private static func appendExtrema(
        in range: Range<Int>,
        samples: [TelemetrySample],
        value: (TelemetrySample) -> Double?,
        to indexes: inout [Int]
    ) {
        let valid = range.compactMap { index -> (Int, Double)? in
            guard let number = value(samples[index]), number.isFinite else { return nil }
            return (index, number)
        }
        if let minimum = valid.min(by: { $0.1 < $1.1 })?.0 { indexes.append(minimum) }
        if let maximum = valid.max(by: { $0.1 < $1.1 })?.0 { indexes.append(maximum) }
    }

    private static func addEvenly(_ candidates: [Int], capacity: Int, to selected: inout Set<Int>) {
        guard capacity > 0 else { return }
        let unique = Array(Set(candidates)).sorted().filter { !selected.contains($0) }
        guard !unique.isEmpty else { return }
        if unique.count <= capacity {
            selected.formUnion(unique)
            return
        }
        for offset in evenlySpacedIndexes(count: unique.count, targetCount: capacity) {
            selected.insert(unique[offset])
        }
    }

    private static func evenlySpacedIndexes(count: Int, targetCount: Int) -> [Int] {
        guard count > 0, targetCount > 0 else { return [] }
        guard targetCount < count else { return Array(0..<count) }
        if targetCount == 1 { return [count / 2] }
        return (0..<targetCount).map { slot in
            Int((Double(slot) * Double(count - 1) / Double(targetCount - 1)).rounded())
        }
    }

    private static func lowerBound(_ samples: [TelemetrySample], timestamp: TimeInterval) -> Int {
        var lower = 0
        var upper = samples.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if samples[middle].capturedAt.timeIntervalSinceReferenceDate < timestamp {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    private static func closestIndex(
        to timestamp: TimeInterval,
        in range: Range<Int>,
        samples: [TelemetrySample]
    ) -> Int {
        range.min { lhs, rhs in
            abs(samples[lhs].capturedAt.timeIntervalSinceReferenceDate - timestamp)
                < abs(samples[rhs].capturedAt.timeIntervalSinceReferenceDate - timestamp)
        } ?? range.lowerBound
    }

    private static func compositeTemperature(_ sample: TelemetrySample) -> Double? {
        [sample.cpuTemperatureC, sample.gpuTemperatureC, sample.socTemperatureC]
            .compactMap { $0 }
            .max()
    }

    private static func relevantFrequency(_ sample: TelemetrySample, mode: StressMode) -> Double? {
        switch mode {
        case .cpu:
            return sample.pClusterFrequencyMHz ?? sample.eClusterFrequencyMHz
        case .gpu:
            return sample.gpuFrequencyMHz
        case .combined:
            return [sample.pClusterFrequencyMHz, sample.gpuFrequencyMHz]
                .compactMap { $0 }
                .min()
        }
    }
}
