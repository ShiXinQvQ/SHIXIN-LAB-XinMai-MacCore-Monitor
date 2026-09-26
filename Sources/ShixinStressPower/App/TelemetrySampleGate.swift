// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import ShixinStressPowerCore

/// Ingest each fresh Helper reading once. Its idle cache is not a new reading
/// when an App reconnects; accepting it creates a false gap at the start.
struct TelemetrySampleGate {
    private var lastHelperSequence: UInt64?

    mutating func accept(_ sample: TelemetrySample) -> Bool {
        // Before the first power sample, sequence stays zero while local sensors
        // continue to change. It is not a cached powermetrics frame to deduplicate.
        if sample.source == .fallback { return true }
        guard let sequence = sample.helperSampleSequence else { return true }
        if let age = sample.helperSampleAgeSeconds, age > 2 { return false }
        guard sequence != lastHelperSequence else { return false }
        lastHelperSequence = sequence
        return true
    }
}
