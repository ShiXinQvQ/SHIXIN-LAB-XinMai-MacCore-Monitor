// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import ShixinNetworkDiagnosticsCore
import ShixinStressPowerCore

@main
struct ShixinStressPowerSelfTest {
    static func main() async {
        if CommandLine.arguments.contains("--cpu-power-debug") {
            await runCPUPowerDebug()
            return
        }
        if CommandLine.arguments.contains("--sample-debug") {
            await runSampleDebug()
            return
        }
        if CommandLine.arguments.contains("--helper-health-debug") {
            runHelperHealthDebug()
            return
        }
        if CommandLine.arguments.contains("--sampling-cadence-debug") {
            await runSamplingCadenceDebug()
            return
        }

        let logicalCPUs = ProcessInfo.processInfo.processorCount
        guard logicalCPUs > 0 else {
            fatalError("processorCount must be greater than zero")
        }

        let configuration = StressConfiguration.default(logicalCPUs: logicalCPUs)
        guard configuration.cpuWorkers == max(1, logicalCPUs),
              configuration.cpuWorkers <= logicalCPUs,
              configuration.thermalSeriousGraceSeconds == 120 else {
            fatalError("default stress configuration is out of sync")
        }
        guard ReleaseConstants.appVersion == "0.3.0-beta",
              ReleaseConstants.appBuild == "300",
              HelperConstants.helperVersion == "0.3.0-helper" else {
            fatalError("release version constants are out of sync")
        }

        verifyPowermetricsPowerParsing()
        verifySustainedPowerCoverage(configuration: configuration)
        verifyFullSessionCurveArchive(configuration: configuration)
        verifyHistoryArchiveAndRecovery(configuration: configuration)
        verifyNetworkQualityParsing()
        verifyNetworkSpeedHistory()
        verifyNetworkDiagnosticsParsingAndScoring()
        verifyNetworkDiagnosticsHistory()

        let sample = TelemetrySample(
            capturedAt: Date(),
            source: .fallback,
            sourceDetail: "test",
            thermalState: "Nominal",
            thermalPressure: nil,
            cpuPowerW: 4,
            gpuPowerW: 6,
            anePowerW: nil,
            packagePowerW: nil,
            cpuActivePercent: 40,
            gpuActivePercent: 20,
            eClusterFrequencyMHz: nil,
            pClusterFrequencyMHz: nil,
            gpuFrequencyMHz: nil,
            cpuTemperatureC: 48,
            gpuTemperatureC: 44,
            socTemperatureC: 44,
            powerSource: .unknown,
            isDegraded: true,
            message: nil,
            fanRPMs: [1800]
        )
        guard sample.totalDisplayedPowerW == 10 else {
            fatalError("totalDisplayedPowerW fallback sum failed")
        }
        guard sample.primaryFanRPM == 1800 else {
            fatalError("primary fan RPM calculation failed")
        }
        var helperProtocolSample = sample
        helperProtocolSample.capturedAt = Date(timeIntervalSince1970: 1_800_000_000.5)
        let helperResponse = HelperResponse(
            ok: true,
            helperVersion: HelperConstants.helperVersion,
            euid: 0,
            sample: helperProtocolSample,
            error: nil
        )
        let helperEncoded = try! JSONEncoder.helperEncoder.encode(helperResponse)
        let helperJSON = String(decoding: helperEncoded, as: UTF8.self)
        let helperDecoded = try! JSONDecoder.helperDecoder.decode(HelperResponse.self, from: helperEncoded)
        guard helperJSON.contains(".500Z"),
              let helperDecodedDate = helperDecoded.sample?.capturedAt,
              abs(helperDecodedDate.timeIntervalSince(helperProtocolSample.capturedAt)) < 0.001 else {
            fatalError("Helper protocol must preserve fractional sample timestamps")
        }
        let legacyHelperEncoder = JSONEncoder()
        legacyHelperEncoder.dateEncodingStrategy = .iso8601
        let legacyHelperEncoded = try! legacyHelperEncoder.encode(helperResponse)
        _ = try! JSONDecoder.helperDecoder.decode(HelperResponse.self, from: legacyHelperEncoded)

        var session = LiveSession(configuration: configuration)
        session.append(sample)
        try? await Task.sleep(nanoseconds: 20_000_000)
        session.append(sample)
        guard session.peakPowerW == 10 else {
            fatalError("peak power calculation failed")
        }
        guard session.peakCPUTemperatureC == 48,
              session.peakGPUTemperatureC == 44,
              session.peakSoCTemperatureC == 44 else {
            fatalError("peak temperature calculation failed")
        }
        let csv = TelemetryCSVExporter.csv(samples: session.samples)
        guard csv.contains("capturedAt,source,sourceDetail,thermalState"),
              csv.contains("totalDisplayedPowerW"),
              csv.contains("fanRPMs"),
              csv.contains("helperSampleSequence"),
              csv.contains("helperSampleAgeSeconds"),
              csv.contains("samplingIntervalMilliseconds"),
              csv.contains("isDegraded") else {
            fatalError("telemetry CSV header missing required fields")
        }
        let summary = session.makeSummary(
            stopReason: .durationReached,
            fullSampleCSVPath: "/tmp/shixin-test.csv",
            fullSampleCSVRelativePath: "Session CSV/shixin-test.csv",
            fullSampleCSVSampleCount: session.samples.count
        )
        guard summary.sampleCount == 2,
              summary.degradedSampleCount == 2,
              summary.savedCurveSampleCount == summary.samples.count,
              summary.fullSampleCSVSampleCount == 2,
              summary.fullSampleCSVPath == "/tmp/shixin-test.csv",
              summary.fullSampleCSVRelativePath == "Session CSV/shixin-test.csv",
              summary.sessionSchemaVersion == 3,
              summary.curveArchiveMetadata?.strategyVersion == 1,
              summary.performanceReport?.fullSampleCSVSampleCount == 2 else {
            fatalError("session summary sample archive metadata failed")
        }
        guard summary.performanceReport != nil else {
            fatalError("session summary should include a performance thermal report")
        }

        var thermalLimitSession = LiveSession(configuration: configuration)
        let thermalStart = Date().addingTimeInterval(-120)
        thermalLimitSession.startedAt = thermalStart
        for index in 0..<30 {
            let isLate = index >= 18
            thermalLimitSession.append(TelemetrySample(
                capturedAt: thermalStart.addingTimeInterval(Double(index) * 4),
                source: .powermetrics,
                sourceDetail: "test powermetrics",
                thermalState: isLate ? "Serious" : "Nominal",
                thermalPressure: isLate ? "heavy" : "nominal",
                cpuPowerW: isLate ? 24 : 36,
                gpuPowerW: isLate ? 14 : 19,
                anePowerW: nil,
                packagePowerW: isLate ? 38 : 55,
                cpuActivePercent: 98,
                gpuActivePercent: 96,
                eClusterFrequencyMHz: 2100,
                pClusterFrequencyMHz: isLate ? 2400 : 3300,
                gpuFrequencyMHz: isLate ? 850 : 1350,
                cpuTemperatureC: isLate ? 91 : 66,
                gpuTemperatureC: isLate ? 86 : 62,
                socTemperatureC: isLate ? 88 : 64,
                powerSource: .unknown,
                isDegraded: false,
                message: nil,
                fanRPMs: [3200]
            ))
        }
        let thermalSummary = thermalLimitSession.makeSummary(stopReason: .durationReached, endedAt: thermalStart.addingTimeInterval(120))
        guard thermalSummary.performanceReport?.stability.level == .possibleThermalLimit,
              thermalSummary.performanceReport?.hasThrottlingHint == true,
              thermalSummary.performanceReport?.validSampleCount == 30,
              thermalSummary.performanceReport?.samplingCompletenessPercent == 100 else {
            fatalError("performance report should flag an obvious late-window thermal limit trend")
        }

        verifyTemperatureRiseDoesNotImplyThrottling(configuration: configuration)
        verifyFragmentedTrendIsInsufficient(configuration: configuration)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let encodedSummaries = try! encoder.encode([thermalSummary])
        let decodedSummaries = try! decoder.decode([StressSessionSummary].self, from: encodedSummaries)
        guard decodedSummaries.first?.performanceReport?.stability.level == .possibleThermalLimit else {
            fatalError("performance report should round-trip through Codable")
        }
        var legacyObject = try! JSONSerialization.jsonObject(with: encodedSummaries) as! [[String: Any]]
        if var report = legacyObject[0]["performanceReport"] as? [String: Any] {
            report.removeValue(forKey: "reportSchemaVersion")
            report.removeValue(forKey: "validSampleCount")
            legacyObject[0]["performanceReport"] = report
            let legacyReportData = try! JSONSerialization.data(withJSONObject: legacyObject)
            let legacyReportDecoded = try! decoder.decode([StressSessionSummary].self, from: legacyReportData)
            guard legacyReportDecoded.first?.performanceReport?.reportSchemaVersion == nil,
                  legacyReportDecoded.first?.performanceReport?.validSampleCount == nil else {
                fatalError("legacy performance report should decode without 0.3.0 optional fields")
            }
        }
        legacyObject[0].removeValue(forKey: "performanceReport")
        let legacyData = try! JSONSerialization.data(withJSONObject: legacyObject)
        let legacyDecoded = try! decoder.decode([StressSessionSummary].self, from: legacyData)
        guard legacyDecoded.first?.performanceReport == nil else {
            fatalError("legacy history without performanceReport should decode with nil report")
        }
        if CommandLine.arguments.contains("--core-only") {
            print("ShixinStressPowerSelfTest core-only passed")
            return
        }
        let telemetrySample = await TelemetrySampler().sample(preferHelper: false)
        guard !telemetrySample.thermalState.isEmpty else {
            fatalError("thermalState fallback must always be populated")
        }
        guard telemetrySample.cpuTemperatureC != nil || telemetrySample.gpuTemperatureC != nil || telemetrySample.socTemperatureC != nil || telemetrySample.isDegraded else {
            fatalError("temperature path should either provide a sensor value or explicitly degrade")
        }
        print("Telemetry source: \(telemetrySample.source.rawValue)")

        let helperPreferredSample = await TelemetrySampler().sample()
        if helperPreferredSample.message?.contains("Helper 需要更新") == true {
            guard helperPreferredSample.cpuTemperatureC != nil || helperPreferredSample.gpuTemperatureC != nil || helperPreferredSample.socTemperatureC != nil else {
                fatalError("outdated helper samples must be locally enriched with temperature data")
            }
            print("Outdated helper temperature enrichment passed")
        }

        for mode in StressMode.allCases {
            let smokeConfiguration = StressConfiguration(
                mode: mode,
                durationSeconds: 1,
                cpuWorkers: 1,
                gpuWorkItems: 16_384,
                gpuIterations: 16,
                thermalSeriousGraceSeconds: 15,
                stopOnCriticalThermalState: true
            )
            let controller = StressController()
            do {
                try await controller.start(configuration: smokeConfiguration)
            } catch {
                fatalError("\(mode.rawValue) stress controller smoke test failed: \(error.localizedDescription)")
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
            let stopStartedAt = Date()
            await controller.stop()
            guard Date().timeIntervalSince(stopStartedAt) < 1.5 else {
                fatalError("\(mode.rawValue) stress smoke stop took too long")
            }
        }

        let responsiveCPUConfiguration = StressConfiguration(
            mode: .cpu,
            durationSeconds: 1,
            cpuWorkers: logicalCPUs,
            gpuWorkItems: 16_384,
            gpuIterations: 16,
            thermalSeriousGraceSeconds: 15,
            stopOnCriticalThermalState: true
        )
        let responsiveController = StressController()
        do {
            try await responsiveController.start(configuration: responsiveCPUConfiguration)
        } catch {
            fatalError("responsive CPU stress start failed: \(error.localizedDescription)")
        }
        try? await Task.sleep(nanoseconds: 250_000_000)
        let stopStartedAt = Date()
        await responsiveController.stop()
        guard Date().timeIntervalSince(stopStartedAt) < 1.5 else {
            fatalError("CPU stress stop took too long")
        }
        print("ShixinStressPowerSelfTest passed")
    }

    private static func verifyNetworkQualityParsing() {
        let modernStream = """
        {"event_type":"progress","downlink_capacity_mbps":12.5}
        {
          "event_type":"final",
          "downlink_capacity_mbps":812.5,
          "uplink_capacity_mbps":112.25,
          "downlink_responsiveness_rpm":780,
          "uplink_responsiveness_rpm":690,
          "idle_latency_ms":18.4,
          "downlink_bytes_transferred":120000000,
          "uplink_bytes_transferred":22000000,
          "interface_name":"en0",
          "test_endpoint":"https://mensura.example.test/api"
        }
        """
        let modern = try! NetworkQualityParser.parse(data: Data(modernStream.utf8))
        guard abs(modern.downloadMbps - 812.5) < 0.001,
              abs(modern.uploadMbps - 112.25) < 0.001,
              modern.latencyMilliseconds == 18.4,
              modern.responsivenessRPM == 690,
              modern.downlinkResponsivenessRPM == 780,
              modern.uplinkResponsivenessRPM == 690,
              modern.downloadedBytes == 120_000_000,
              modern.uploadedBytes == 22_000_000,
              modern.interfaceName == "en0",
              modern.testEndpointHost == "mensura.example.test" else {
            fatalError("modern networkQuality stream parsing failed")
        }

        let liveStream = """
        {"event_type":"progress","progress":18,"downlink_capacity_mbps":240.5}
        {
          "event_type":"progress",
          "progress":43,
          "downlink_capacity_mbps":612.75,
          "uplink_capacity_mbps":84.25,
          "downlink_responsiveness_rpm":720,
          "uplink_responsiveness_rpm":680,
          "idle_latency_ms":19.5,
          "downlink_bytes_transferred":54000000,
          "uplink_bytes_transferred":9000000,
          "interface_name":"en1",
          "test_endpoint":"https://progress.example.test/api"
        }
        """
        guard let live = NetworkQualityParser.latestLiveMeasurement(
            in: Data(liveStream.utf8)
        ),
        let fractionCompleted = live.fractionCompleted,
        abs(fractionCompleted - 0.43) < 0.001,
        live.downloadMbps == 612.75,
        live.uploadMbps == 84.25,
        live.latencyMilliseconds == 19.5,
        live.responsivenessRPM == 680,
        live.downloadedBytes == 54_000_000,
        live.uploadedBytes == 9_000_000,
        live.interfaceName == "en1",
        live.testEndpointHost == "progress.example.test" else {
            fatalError("live networkQuality progress parsing failed")
        }

        let legacyJSON = """
        {
          "dl_throughput": 450000000,
          "ul_throughput": 55000000,
          "responsiveness": 620,
          "dl_responsiveness": 650,
          "ul_responsiveness": 620,
          "base_rtt": 23.5,
          "dl_bytes_transferred": 80000000,
          "ul_bytes_transferred": 12000000
        }
        """
        let legacy = try! NetworkQualityParser.parse(data: Data(legacyJSON.utf8))
        guard abs(legacy.downloadMbps - 450) < 0.001,
              abs(legacy.uploadMbps - 55) < 0.001,
              legacy.latencyMilliseconds == 23.5,
              legacy.responsivenessRPM == 620 else {
            fatalError("legacy networkQuality parsing failed")
        }

        let errorJSON = """
        {"error_code":-1003,"error_domain":"NSURLErrorDomain","error_description":"A server with the specified hostname could not be found."}
        """
        do {
            _ = try NetworkQualityParser.parse(data: Data(errorJSON.utf8))
            fatalError("networkQuality error output must not decode as a result")
        } catch let error as NetworkSpeedTestError {
            guard case .networkQualityFailure(code: -1003, _, _) = error else {
                fatalError("networkQuality error output returned the wrong error")
            }
        } catch {
            fatalError("networkQuality error output returned an unexpected error")
        }
    }

    private static func verifyNetworkSpeedHistory() {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("shixin-network-history-selftest-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        let store = NetworkSpeedHistoryStore(
            fileManager: fileManager,
            appSupportURL: root,
            maximumRecords: 2
        )
        let baseDate = Date(timeIntervalSinceReferenceDate: 820_000_000)

        func record(index: Int) -> NetworkSpeedTestRecord {
            let startedAt = baseDate.addingTimeInterval(Double(index) * 60)
            return NetworkSpeedTestRecord(
                startedAt: startedAt,
                completedAt: startedAt.addingTimeInterval(18),
                downloadMbps: 500 + Double(index),
                uploadMbps: 80 + Double(index),
                latencyMilliseconds: 20 + Double(index),
                jitterMilliseconds: 3 + Double(index),
                responsivenessRPM: 600 + index,
                downlinkResponsivenessRPM: 650 + index,
                uplinkResponsivenessRPM: 600 + index,
                downloadedBytes: 100_000_000,
                uploadedBytes: 20_000_000,
                interfaceName: "en0",
                serverName: "macOS 默认网络质量服务"
            )
        }

        do {
            _ = try store.append(record(index: 0))
            _ = try store.append(record(index: 1))
            let saved = try store.append(record(index: 2))
            let loaded = try store.load()
            guard saved.count == 2,
                  loaded.count == 2,
                  loaded.map(\.downloadMbps) == [502, 501],
                  fileManager.fileExists(atPath: store.historyURL.path) else {
                fatalError("network speed history cap or round-trip failed")
            }

            _ = try store.append(record(index: 3))
            try Data("{broken-network-speed-history".utf8).write(
                to: store.historyURL,
                options: [.atomic]
            )
            let recovered = try store.load()
            _ = try store.append(record(index: 4))
            guard !recovered.isEmpty,
                  try store.load().first?.downloadMbps == 504 else {
                fatalError("network speed history corruption recovery failed")
            }
        } catch {
            fatalError("network speed history self test failed: \(error.localizedDescription)")
        }

        let fiftyRecordStore = NetworkSpeedHistoryStore(
            fileManager: fileManager,
            appSupportURL: root.appendingPathComponent("fifty-record-cap", isDirectory: true)
        )
        do {
            var saved: [NetworkSpeedTestRecord] = []
            for index in 0...50 {
                saved = try fiftyRecordStore.append(record(index: index))
            }
            guard saved.count == 50,
                  saved.first?.downloadMbps == 550,
                  saved.last?.downloadMbps == 501 else {
                fatalError("network speed history default 50-record cap failed")
            }
        } catch {
            fatalError("network speed 50-record cap self test failed: \(error.localizedDescription)")
        }
    }

    private static func verifyNetworkDiagnosticsParsingAndScoring() {
        let ipWhoFixture = """
        {
          "ip": "203.0.113.10",
          "success": true,
          "type": "IPv4",
          "country": "Exampleland",
          "country_code": "EX",
          "region": "Example Region",
          "city": "Example City",
          "latitude": 10.5,
          "longitude": 20.5,
          "connection": {
            "asn": 64500,
            "org": "Example Network",
            "isp": "Example ISP"
          },
          "timezone": {"id": "Etc/UTC"}
        }
        """
        let publicProfile = try! IPWhoIsParser.parse(data: Data(ipWhoFixture.utf8))
        guard publicProfile.ip == "203.0.113.10",
              publicProfile.countryCode == "EX",
              publicProfile.asn == "AS64500",
              publicProfile.asOrganization == "Example Network",
              publicProfile.timezoneIdentifier == "Etc/UTC" else {
            fatalError("ipwho.is provider parsing failed")
        }

        let proxyCheckFixture = """
        {
          "status": "ok",
          "203.0.113.10": {
            "ip": "203.0.113.10",
            "risk": 50,
            "last_updated": "2026-07-28T12:00:00Z",
            "network": {
              "asn": "AS64500",
              "provider": "Example ISP",
              "organisation": "Example Network",
              "type": "Hosting"
            },
            "detections": {
              "anonymous": true,
              "scraper": false,
              "vpn": true,
              "proxy": false,
              "tor": false,
              "hosting": true,
              "compromised": false,
              "confidence": 95,
              "first_seen": "2026-07-01T00:00:00Z",
              "last_seen": "2026-07-27T18:00:00Z"
            },
            "attack_history": {
              "login_attempt": 2,
              "registration_attempt": 3
            },
            "operator": {
              "name": "Example VPN",
              "services": ["datacenter_vpns"]
            }
          }
        }
        """
        let riskProfile = try! ProxyCheckParser.parse(
            data: Data(proxyCheckFixture.utf8),
            queriedIP: "203.0.113.10"
        )
        guard riskProfile.isVPN == true,
              riskProfile.isProxy == false,
              riskProfile.isAnonymous == true,
              riskProfile.isScraper == false,
              riskProfile.isHosting == true,
              riskProfile.isCompromised == false,
              riskProfile.riskScore == 50,
              riskProfile.providerConfidence == 95,
              riskProfile.attackCount == 5,
              riskProfile.isResidentialProxy == false,
              riskProfile.lastSeen == "2026-07-27T18:00:00Z",
              riskProfile.lastUpdated == "2026-07-28T12:00:00Z",
              riskProfile.asn == "AS64500" else {
            fatalError("proxycheck.io provider parsing failed")
        }
        let warningFixture = """
        {
          "status": "warning",
          "198.51.100.8": {
            "risk": 33,
            "last_updated": "2026-07-28T12:05:00Z",
            "network": {
              "asn": "AS64501",
              "provider": "Example Hosting",
              "organisation": "Example Hosting",
              "type": "Hosting"
            },
            "detections": {
              "anonymous": false,
              "scraper": false,
              "vpn": false,
              "proxy": false,
              "tor": false,
              "hosting": true,
              "compromised": false,
              "confidence": null,
              "first_seen": null,
              "last_seen": null
            },
            "attack_history": {},
            "operator": null
          }
        }
        """
        let warningProfile = try! ProxyCheckParser.parse(
            data: Data(warningFixture.utf8),
            queriedIP: "198.51.100.8"
        )
        guard warningProfile.riskScore == 33,
              warningProfile.attackCount == 0,
              warningProfile.isVPN == false,
              warningProfile.isAnonymous == false,
              warningProfile.isScraper == false,
              warningProfile.isResidentialProxy == false,
              warningProfile.providerConfidence == nil else {
            fatalError("proxycheck.io warning/clean-result parsing failed")
        }

        let cleanRiskFixture = """
        {
          "status": "ok",
          "198.51.100.9": {
            "risk": 0,
            "last_updated": "2026-07-28T12:06:00Z",
            "network": {"type": "Residential"},
            "detections": {
              "anonymous": false,
              "scraper": false,
              "vpn": false,
              "proxy": false,
              "tor": false,
              "hosting": false,
              "compromised": false,
              "confidence": 100,
              "last_seen": null
            },
            "attack_history": null,
            "operator": null
          }
        }
        """
        let cleanRiskProfile = try! ProxyCheckParser.parse(
            data: Data(cleanRiskFixture.utf8),
            queriedIP: "198.51.100.9"
        )
        guard cleanRiskProfile.riskScore == 0,
              cleanRiskProfile.attackCount == 0,
              cleanRiskProfile.isAnonymous == false,
              cleanRiskProfile.isScraper == false,
              cleanRiskProfile.lastSeen == nil else {
            fatalError("proxycheck.io clean/null-history parsing failed")
        }

        let successfulTargets = InternationalTargetID.allCases.map {
            successfulDiagnosticTarget(id: $0)
        }
        let fullAssessment = InternationalAssessmentEngine.assess(successfulTargets)
        guard fullAssessment.score == 100,
              fullAssessment.completeness == 1,
              fullAssessment.confidence == 1,
              fullAssessment.grade == .excellent else {
            fatalError("complete international diagnostics scoring failed")
        }
        let operationalAssessment =
            InternationalOperationalAssessmentEngine.assess(successfulTargets)
        guard operationalAssessment.protocolSuccess.score == 100,
              operationalAssessment.latencyQuality.score != nil,
              operationalAssessment.connectionStability.score == 100,
              operationalAssessment.addressFamilyCoverage.score == 100 else {
            fatalError("operational diagnostics scoring failed")
        }

        let dnsFailureAttempts = (0..<3).map { index in
            InternationalProbeAttempt(
                startedAt: Date(timeIntervalSinceReferenceDate: 830_000_000 + Double(index)),
                dnsMilliseconds: 8,
                connectMilliseconds: nil,
                tlsMilliseconds: nil,
                ttfbMilliseconds: nil,
                totalMilliseconds: 8,
                statusCode: nil,
                finalHost: InternationalTargetID.x.host,
                resolvedIPv4: false,
                resolvedIPv6: false,
                usedIPVersion: nil,
                usedProxy: nil,
                errorKind: .dnsFailure,
                errorDescription: "fixture"
            )
        }
        let failedTarget = InternationalTargetResult(
            id: .x,
            attempts: dnsFailureAttempts
        )
        var singleFailureResults = successfulTargets.filter { $0.id != .x }
        singleFailureResults.append(failedTarget)
        let degradedAssessment = InternationalAssessmentEngine.assess(singleFailureResults)
        guard InternationalAssessmentEngine.targetStatus(failedTarget) == .unavailable,
              let degradedScore = degradedAssessment.score,
              degradedScore > 0,
              degradedScore < 100,
              degradedAssessment.completeness < 1 else {
            fatalError("single-target failure must degrade without invalidating the full route")
        }

        let cancelledTarget = InternationalTargetResult(
            id: .github,
            requestedAttemptCount: 3,
            attempts: [
                InternationalProbeAttempt(
                    dnsMilliseconds: nil,
                    connectMilliseconds: nil,
                    tlsMilliseconds: nil,
                    ttfbMilliseconds: nil,
                    totalMilliseconds: nil,
                    statusCode: nil,
                    finalHost: nil,
                    resolvedIPv4: false,
                    resolvedIPv6: false,
                    usedIPVersion: nil,
                    usedProxy: nil,
                    errorKind: .cancelled,
                    errorDescription: nil
                )
            ]
        )
        let cancelledAssessment = InternationalAssessmentEngine.assess([cancelledTarget])
        guard cancelledAssessment.score == nil,
              cancelledAssessment.completeness == 0,
              InternationalAssessmentEngine.targetStatus(cancelledTarget) == .insufficient else {
            fatalError("cancelled diagnostics must never appear complete or perfect")
        }

        for errorKind in [
            InternationalProbeErrorKind.offline,
            .timeout,
            .dnsFailure,
            .connectionFailure,
            .connectionReset,
            .tlsFailure
        ] {
            let reachedDNS = errorKind != .dnsFailure
            let reachedTCP = errorKind == .tlsFailure
            let attempts = (0..<3).map { _ in
                InternationalProbeAttempt(
                    dnsMilliseconds: 12,
                    connectMilliseconds: reachedTCP ? 35 : nil,
                    tlsMilliseconds: nil,
                    ttfbMilliseconds: nil,
                    totalMilliseconds: 150,
                    statusCode: nil,
                    finalHost: InternationalTargetID.github.host,
                    resolvedIPv4: reachedDNS,
                    resolvedIPv6: false,
                    usedIPVersion: reachedDNS ? "IPv4" : nil,
                    usedProxy: nil,
                    errorKind: errorKind,
                    errorDescription: "fixture"
                )
            }
            let result = InternationalTargetResult(id: .github, attempts: attempts)
            let assessment = InternationalAssessmentEngine.assess([result])
            guard InternationalAssessmentEngine.targetStatus(result) == .unavailable,
                  assessment.score != 100,
                  assessment.grade != .excellent else {
                fatalError("\(errorKind.rawValue) degradation must not appear successful")
            }
        }

        let rateLimitedTarget = InternationalTargetResult(
            id: .instagram,
            attempts: (0..<3).map { _ in
                InternationalProbeAttempt(
                    dnsMilliseconds: 10,
                    connectMilliseconds: 22,
                    tlsMilliseconds: 28,
                    ttfbMilliseconds: 120,
                    totalMilliseconds: 160,
                    statusCode: 429,
                    finalHost: InternationalTargetID.instagram.host,
                    resolvedIPv4: true,
                    resolvedIPv6: true,
                    usedIPVersion: "IPv4",
                    usedProxy: false,
                    errorKind: .httpAbnormal,
                    errorDescription: nil
                )
            }
        )
        guard InternationalAssessmentEngine.targetStatus(rateLimitedTarget) == .partial else {
            fatalError("HTTP throttling must be a target response anomaly, not a route failure")
        }

        let attributeOnlyProfile = IPRiskProfile(
            ip: "203.0.113.11",
            isVPN: true,
            isProxy: false,
            isTor: false,
            isRelay: false,
            isHosting: true,
            isResidentialProxy: false,
            isCompromised: false,
            isAnycast: nil,
            riskScore: 0,
            attackCount: 0,
            networkType: "Hosting",
            provider: "Example ISP",
            asn: "AS64500",
            organization: "Example Network",
            lastSeen: nil,
            source: "fixture"
        )
        let reputation = IPReputationAssessmentEngine.assess(attributeOnlyProfile)
        guard reputation.score == 94,
              reputation.confidence <= 0.65,
              reputation.signals.contains(where: { $0.id == "reputation.vpn" }),
              reputation.signals.contains(where: { $0.id == "reputation.hosting" }) else {
            fatalError("VPN and hosting attributes must remain separate from malicious risk")
        }
        let signalledReputation = IPReputationAssessmentEngine.assess(riskProfile)
        guard let signalledScore = signalledReputation.score,
              signalledScore < 94,
              signalledReputation.signals.contains(where: {
                  $0.id == "reputation.attacks"
              }),
              signalledReputation.signals.contains(where: {
                  $0.id == "reputation.provider-risk"
              }) else {
            fatalError("provider risk and attack history must remain explicit deductions")
        }

        let privacy = PrivacyConsistencyAssessmentEngine.assess(
            PrivacyConsistencyInput(
                ipv4CountryCode: "US",
                ipv6CountryCode: "DE",
                ipv4ASN: "AS64500",
                ipv6ASN: "AS64501",
                publicEndpointAgreement: nil,
                timeZoneMatchesExit: false,
                localeMatchesExit: nil,
                proxyEnabled: true,
                tunnelInterfaceCount: 1,
                primaryInterfaceIsTunnel: true,
                possibleIPv6Bypass: true
            )
        )
        guard let privacyScore = privacy.score,
              privacyScore < 60,
              privacy.completeness < 1,
              privacy.confidence < 1,
              privacy.signals.contains(where: { $0.id == "privacy.dns-unverified" }),
              privacy.signals.contains(where: { $0.id == "privacy.webrtc-unverified" }) else {
            fatalError("privacy scoring must expose split egress and unavailable leak evidence")
        }

        let insufficientCombined = CombinedNetworkAssessmentEngine.assess(
            international: fullAssessment,
            reputation: nil,
            privacy: nil
        )
        guard insufficientCombined.score == nil,
              insufficientCombined.grade == .insufficient else {
            fatalError("combined scoring must require at least two usable components")
        }
    }

    private static func verifyNetworkDiagnosticsHistory() {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "shixin-network-diagnostics-history-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? fileManager.removeItem(at: root) }
        let store = NetworkDiagnosticsHistoryStore(
            fileManager: fileManager,
            appSupportURL: root,
            maximumRecords: 2
        )
        let targets = InternationalTargetID.allCases.map {
            successfulDiagnosticTarget(id: $0)
        }
        let international = InternationalAssessmentEngine.assess(targets)
        let baseDate = Date(timeIntervalSinceReferenceDate: 831_000_000)

        func record(index: Int) -> NetworkDiagnosticsRecord {
            let startedAt = baseDate.addingTimeInterval(Double(index) * 60)
            let combined = CombinedNetworkAssessmentEngine.assess(
                international: international,
                reputation: ScoreAssessment(
                    score: 90,
                    completeness: 0.8,
                    confidence: 0.6,
                    signals: []
                ),
                privacy: nil
            )
            return NetworkDiagnosticsRecord(
                startedAt: startedAt,
                completedAt: startedAt.addingTimeInterval(12),
                targets: targets,
                internationalAssessment: international,
                publicSummary: PublicNetworkHistorySummary(
                    countryCode: "EX",
                    asn: "AS64500",
                    networkType: "Residential",
                    sources: ["fixture"]
                ),
                reputationAssessment: ScoreAssessment(
                    score: 90,
                    completeness: 0.8,
                    confidence: 0.6,
                    signals: []
                ),
                privacyAssessment: nil,
                combinedAssessment: combined
            )
        }

        do {
            _ = try store.append(record(index: 0))
            _ = try store.append(record(index: 1))
            let saved = try store.append(record(index: 2))
            let loaded = try store.load()
            let persistedData = try Data(contentsOf: store.historyURL)
            let persistedText = String(decoding: persistedData, as: UTF8.self)
            guard saved.count == 2,
                  loaded.count == 2,
                  loaded.first?.completedAt == record(index: 2).completedAt,
                  !persistedText.contains("203.0.113.10"),
                  persistedText.contains("AS64500") else {
                fatalError("network diagnostics history cap, order, or privacy boundary failed")
            }
            _ = try store.append(record(index: 3))
            try Data("{broken-network-diagnostics-history".utf8).write(
                to: store.historyURL,
                options: [.atomic]
            )
            let recovered = try store.load()
            _ = try store.append(record(index: 4))
            guard !recovered.isEmpty,
                  try store.load().first?.completedAt == record(index: 4).completedAt else {
                fatalError("network diagnostics history corruption recovery failed")
            }
        } catch {
            fatalError("network diagnostics history self test failed: \(error.localizedDescription)")
        }
    }

    private static func successfulDiagnosticTarget(
        id: InternationalTargetID
    ) -> InternationalTargetResult {
        var attempts: [InternationalProbeAttempt] = []
        for index in 0..<3 {
            let attempt = InternationalProbeAttempt(
                startedAt: Date(
                    timeIntervalSinceReferenceDate: 830_000_000 + Double(index)
                ),
                dnsMilliseconds: 8 + Double(index),
                connectMilliseconds: 20 + Double(index),
                tlsMilliseconds: 30 + Double(index),
                ttfbMilliseconds: 90 + Double(index),
                totalMilliseconds: 180 + Double(index) * 4,
                statusCode: 204,
                responseBytes: 0,
                finalHost: id.host,
                redirectCount: 0,
                resolvedIPv4: true,
                resolvedIPv6: true,
                usedIPVersion: index.isMultiple(of: 2) ? "IPv4" : "IPv6",
                usedProxy: false,
                errorKind: nil,
                errorDescription: nil
            )
            attempts.append(attempt)
        }
        return InternationalTargetResult(id: id, attempts: attempts)
    }

    private static func runCPUPowerDebug() async {
        let logicalCPUs = ProcessInfo.processInfo.processorCount
        let configuration = StressConfiguration(
            mode: .cpu,
            durationSeconds: 10,
            cpuWorkers: logicalCPUs,
            gpuWorkItems: 16_384,
            gpuIterations: 16,
            thermalSeriousGraceSeconds: 15,
            stopOnCriticalThermalState: false
        )
        let controller = StressController()
        do {
            try await controller.start(configuration: configuration)
            print("CPU power debug started with \(logicalCPUs) workers")
            for index in 1...7 {
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                do {
                    let sample = try HelperSocketClient.sample()
                    let package = Formatters.watts(sample.packagePowerW ?? sample.totalDisplayedPowerW)
                    let cpu = Formatters.watts(sample.cpuPowerW)
                    let active = Formatters.percent(sample.cpuActivePercent)
                    let temp = Formatters.celsius(sample.cpuTemperatureC)
                    print("sample \(index): package=\(package) cpu=\(cpu) active=\(active) temp=\(temp) degraded=\(sample.isDegraded)")
                } catch {
                    print("sample \(index): helper sample failed: \(error.localizedDescription)")
                }
            }
            await controller.stop()
            print("CPU power debug stopped")
        } catch {
            print("CPU power debug start failed: \(error.localizedDescription)")
            await controller.stop()
        }
    }

    private static func runSampleDebug() async {
        let sampler = TelemetrySampler()
        var lastSequence: UInt64?
        var uniqueSamples = 0
        let startedAt = Date()
        for index in 1...8 {
            let sample = await sampler.sample()
            if sample.helperSampleSequence == nil || sample.helperSampleSequence != lastSequence {
                uniqueSamples += 1
                lastSequence = sample.helperSampleSequence
            }
            print(
                "sample \(index): seq=\(sample.helperSampleSequence.map(String.init) ?? "legacy") age=\(sample.helperSampleAgeSeconds.map { String(format: "%.3f", $0) } ?? "-")s interval=\(sample.samplingIntervalMilliseconds.map(String.init) ?? "-")ms cpuActive=\(Formatters.percent(sample.cpuActivePercent)) gpuActive=\(Formatters.percent(sample.gpuActivePercent)) cpuPower=\(Formatters.watts(sample.cpuPowerW)) source=\(sample.sourceDetail)"
            )
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        print("sample debug: \(uniqueSamples) unique samples in \(String(format: "%.2f", Date().timeIntervalSince(startedAt))) seconds")
    }

    private static func runHelperHealthDebug() {
        do {
            let info = try HelperSocketClient.info()
            let health = info.samplingHealth
            let sequence = health.map { String($0.sequence) } ?? "-"
            let age = health?.sampleAgeSeconds.map { String(format: "%.3f", $0) } ?? "-"
            let interval = health.map { String($0.intervalMilliseconds) } ?? "-"
            print(
                "helper=\(info.helperVersion) state=\(health?.state ?? "legacy") seq=\(sequence) age=\(age)s interval=\(interval)ms error=\(health?.lastError ?? "none")"
            )
        } catch {
            print("helper health failed: \(error.localizedDescription)")
            exit(2)
        }
    }

    private static func runSamplingCadenceDebug() async {
        let sampler = TelemetrySampler()
        let startedAt = Date()
        let deadline = startedAt.addingTimeInterval(18)
        var firstSampleLatency: TimeInterval?
        var lastSequence: UInt64?
        var arrivals: [Date] = []

        while Date() < deadline, arrivals.count < 20 {
            let sample = await sampler.sample()
            if let sequence = sample.helperSampleSequence,
               sequence != lastSequence,
               sample.source == .powermetrics,
               !sample.isDegraded,
               (sample.helperSampleAgeSeconds ?? .infinity) <= 2 {
                let now = Date()
                if firstSampleLatency == nil {
                    firstSampleLatency = now.timeIntervalSince(startedAt)
                }
                arrivals.append(now)
                lastSequence = sequence
                print("cadence sample \(arrivals.count): seq=\(sequence) age=\(String(format: "%.3f", sample.helperSampleAgeSeconds ?? 0))s")
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        let intervals = zip(arrivals, arrivals.dropFirst())
            .map { $1.timeIntervalSince($0) }
            .sorted()
        guard intervals.count >= 5 else {
            fatalError("sampling cadence check did not receive enough trusted helper samples")
        }
        let median = percentile(intervals, fraction: 0.5)
        let p95 = percentile(intervals, fraction: 0.95)
        let passesTarget = median <= 0.7 && p95 < 1.0 && (firstSampleLatency ?? .infinity) <= 4
        print(
            "sampling cadence: first=\(String(format: "%.3f", firstSampleLatency ?? 0))s "
                + "median=\(String(format: "%.3f", median))s "
                + "p95=\(String(format: "%.3f", p95))s "
                + "result=\(passesTarget ? "PASS" : "REVIEW")"
        )
        guard passesTarget else {
            fatalError("sampling cadence missed the first-sample, median, or P95 acceptance target")
        }
    }

    private static func percentile(_ sortedValues: [Double], fraction: Double) -> Double {
        guard !sortedValues.isEmpty else { return .infinity }
        let rank = Int(ceil(fraction * Double(sortedValues.count))) - 1
        return sortedValues[max(0, min(sortedValues.count - 1, rank))]
    }

    private static func verifyPowermetricsPowerParsing() {
        let root: [String: Any] = [
            "timestamp": Date(),
            "thermal_pressure": "Nominal",
            "processor": [
                "cpu_power": 42_000,
                "gpu_power": 18_000,
                "ane_power": 1_500,
                "combined_power": 63_000,
                "clusters": [
                    ["name": "E0", "freq_hz": 2_100_000_000.0, "idle_ratio": 0.2],
                    ["name": "P0", "freq_hz": 3_200_000_000.0, "idle_ratio": 0.1]
                ]
            ],
            "gpu": ["freq_hz": 1_350_000_000.0, "idle_ratio": 0.05]
        ]
        let directData = try! PropertyListSerialization.data(fromPropertyList: root, format: .xml, options: 0)
        let direct = try! PowermetricsParser.parse(
            output: directData,
            fallbackThermalState: "Nominal",
            powerSource: .unknown,
            sampleIntervalSeconds: 0.5
        )
        guard direct.cpuPowerW == 42,
              direct.gpuPowerW == 18,
              direct.anePowerW == 1.5,
              direct.packagePowerW == 63 else {
            fatalError("powermetrics direct power fields must be parsed as milliwatts")
        }

        var energyRoot = root
        energyRoot["processor"] = [
            "cpu_energy": 21_000,
            "gpu_energy": 9_000,
            "ane_energy": 750,
            "combined_power": 63_000,
            "clusters": (root["processor"] as! [String: Any])["clusters"]!
        ]
        let energyData = try! PropertyListSerialization.data(fromPropertyList: energyRoot, format: .xml, options: 0)
        let energy = try! PowermetricsParser.parse(
            output: energyData,
            fallbackThermalState: "Nominal",
            powerSource: .unknown,
            sampleIntervalSeconds: 0.5
        )
        guard energy.cpuPowerW == 42,
              energy.gpuPowerW == 18,
              energy.anePowerW == 1.5 else {
            fatalError("powermetrics energy fallback must be normalized by the sample interval")
        }
    }

    private static func verifySustainedPowerCoverage(configuration: StressConfiguration) {
        let start = Date().addingTimeInterval(-301)
        var shortSession = LiveSession(configuration: configuration)
        shortSession.startedAt = start
        for second in 0...61 {
            shortSession.append(powerSample(at: start.addingTimeInterval(Double(second)), watts: 50))
        }
        guard shortSession.sustainedPower60sW == 50,
              shortSession.sustainedPower300sW == nil else {
            fatalError("a one-minute session must not report five-minute sustained power")
        }

        var legacyShortSummary = shortSession.makeSummary(
            stopReason: .durationReached,
            endedAt: start.addingTimeInterval(61)
        )
        legacyShortSummary.sustainedPower300sW = 50
        legacyShortSummary.performanceReport?.sustainedPower300sW = 50
        guard legacyShortSummary.validatedSustainedPower60sW == 50,
              legacyShortSummary.validatedSustainedPower300sW == nil,
              legacyShortSummary.performanceReport?.validatedSustainedPower300sW == nil else {
            fatalError("legacy summaries must hide sustained values that exceed their actual duration")
        }

        var longSession = LiveSession(configuration: configuration)
        longSession.startedAt = start
        for second in 0...300 {
            longSession.append(powerSample(at: start.addingTimeInterval(Double(second)), watts: 55))
        }
        guard longSession.sustainedPower300sW == 55 else {
            fatalError("five-minute sustained power should require and accept full time coverage")
        }
    }

    private static func verifyTemperatureRiseDoesNotImplyThrottling(configuration: StressConfiguration) {
        var session = LiveSession(configuration: configuration)
        let start = Date().addingTimeInterval(-120)
        session.startedAt = start
        for index in 0..<30 {
            let late = index >= 18
            session.append(TelemetrySample(
                capturedAt: start.addingTimeInterval(Double(index) * 4),
                source: .powermetrics,
                sourceDetail: "test powermetrics",
                thermalState: "Nominal",
                thermalPressure: "nominal",
                cpuPowerW: 35,
                gpuPowerW: 18,
                anePowerW: nil,
                packagePowerW: 54,
                cpuActivePercent: 98,
                gpuActivePercent: 96,
                eClusterFrequencyMHz: 2100,
                pClusterFrequencyMHz: 3300,
                gpuFrequencyMHz: 1350,
                cpuTemperatureC: late ? 88 : 62,
                gpuTemperatureC: late ? 82 : 58,
                socTemperatureC: late ? 85 : 60,
                powerSource: .unknown,
                isDegraded: false,
                message: nil
            ))
        }
        let summary = session.makeSummary(stopReason: .durationReached, endedAt: start.addingTimeInterval(120))
        guard summary.performanceReport?.stability.level == .stable,
              summary.performanceReport?.hasThrottlingHint == false else {
            fatalError("temperature rise alone must not be reported as frequency throttling")
        }
    }

    private static func verifyFragmentedTrendIsInsufficient(configuration: StressConfiguration) {
        var session = LiveSession(configuration: configuration)
        let start = Date().addingTimeInterval(-120)
        session.startedAt = start
        let offsets: [TimeInterval] = [
            0, 0.5, 1, 1.5, 2,
            45, 45.5, 46, 46.5, 47,
            72, 72.5, 73, 73.5, 74,
            115, 115.5, 116, 116.5, 117
        ]
        for offset in offsets {
            session.append(powerSample(at: start.addingTimeInterval(offset), watts: 52))
        }
        let summary = session.makeSummary(stopReason: .durationReached, endedAt: start.addingTimeInterval(120))
        guard summary.performanceReport?.stability.level == .insufficientData else {
            fatalError("fragmented samples must not be reported as a stable performance trend")
        }
    }

    private static func verifyFullSessionCurveArchive(configuration: StressConfiguration) {
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshot = SessionEnvironmentSnapshot(
            capturedAt: start,
            modelName: "MacBook Pro",
            modelIdentifier: "Mac-Test,1",
            soc: "Apple M Test",
            cpuCores: "16 核心",
            gpuCores: "40 内核",
            systemMemory: "48 GB",
            systemVersion: "macOS Test",
            kernelVersion: "Darwin Test"
        )
        var session = LiveSession(configuration: configuration, environmentSnapshot: snapshot)
        session.startedAt = start
        var peakPowerID: UUID?
        var peakTemperatureID: UUID?

        for index in 0...3600 {
            let gapOffset = index >= 1800 ? 8.0 : 0.0
            let date = start.addingTimeInterval(Double(index) * 0.5 + gapOffset)
            let power = index == 1200 ? 180.0 : 55 + sin(Double(index) / 70) * 8
            var sample = powerSample(at: date, watts: power)
            sample.cpuTemperatureC = index == 2400 ? 120 : 70 + sin(Double(index) / 90) * 6
            sample.gpuTemperatureC = 64 + sin(Double(index) / 110) * 5
            sample.socTemperatureC = 68 + sin(Double(index) / 100) * 5
            sample.thermalState = index >= 2500 && index < 2520 ? "Serious" : "Nominal"
            sample.isDegraded = index >= 2800 && index < 2810
            if index == 1200 { peakPowerID = sample.id }
            if index == 2400 { peakTemperatureID = sample.id }
            session.append(sample)
        }

        let endedAt = session.samples.last!.capturedAt
        let summary = session.makeSummary(stopReason: .durationReached, endedAt: endedAt)
        let minimumArchive = TelemetryCurveCompressor.archive(
            samples: session.samples,
            maxSamples: 2,
            mode: configuration.mode
        )
        guard summary.sampleCount == 3601,
              summary.samples.count <= 900,
              summary.samples.first?.id == session.samples.first?.id,
              summary.samples.last?.id == session.samples.last?.id,
              summary.samples.contains(where: { $0.id == peakPowerID }),
              summary.samples.contains(where: { $0.id == peakTemperatureID }),
              summary.peakPowerW == 180,
              summary.environmentSnapshot?.modelIdentifier == "Mac-Test,1",
              summary.curveArchiveMetadata?.originalSampleCount == 3601,
              summary.curveArchiveMetadata?.samplingGapCount == 1,
              (summary.curveArchiveMetadata?.largestSamplingGapSeconds ?? 0) > 8,
              summary.curveArchiveMetadata?.samplingGaps?.count == 1,
              summary.curveArchiveMetadata?.samplingGaps?.first?.startedAt == session.samples[1799].capturedAt,
              summary.curveArchiveMetadata?.samplingGaps?.first?.endedAt == session.samples[1800].capturedAt,
              minimumArchive.samples.map(\.id) == [session.samples.first!.id, session.samples.last!.id],
              summary.performanceReport?.reportSchemaVersion == 3,
              summary.performanceReport?.samplingGapCount == 1,
              (summary.performanceReport?.timeCoveragePercent ?? 0) > 99 else {
            fatalError("full-session curve archive must preserve time span, extrema, gaps, and environment snapshot")
        }
    }

    private static func verifyHistoryArchiveAndRecovery(configuration: StressConfiguration) {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("shixin-history-selftest-\(UUID().uuidString)", isDirectory: true)
        let outsideURL = root.deletingLastPathComponent()
            .appendingPathComponent("shixin-history-outside-\(UUID().uuidString).csv")
        defer {
            try? fileManager.removeItem(at: root)
            try? fileManager.removeItem(at: outsideURL)
        }
        let store = HistoryStore(fileManager: fileManager, appSupportURL: root)
        var session = LiveSession(configuration: configuration)
        session.startedAt = Date(timeIntervalSinceReferenceDate: 810_000_000)
        session.append(powerSample(at: session.startedAt, watts: 40))
        session.append(powerSample(at: session.startedAt.addingTimeInterval(0.5), watts: 42))
        let summary = session.makeSummary(stopReason: .durationReached, endedAt: session.startedAt.addingTimeInterval(0.5))

        do {
            try store.ensureDirectories()
            let historyEncoder = JSONEncoder()
            historyEncoder.dateEncodingStrategy = .iso8601
            let historyDecoder = JSONDecoder()
            historyDecoder.dateDecodingStrategy = .iso8601
            let legacyData = try historyEncoder.encode([summary])
            try legacyData.write(to: store.sessionsURL, options: [.atomic])
            guard try store.loadSessions().count == 1 else {
                fatalError("legacy history array must remain readable")
            }

            try store.saveSessions([summary])
            let envelopeData = try Data(contentsOf: store.sessionsURL)
            let envelope = try historyDecoder.decode(HistoryArchive.self, from: envelopeData)
            guard envelope.schemaVersion == HistoryStore.currentSchemaVersion,
                  envelope.sessions.count == 1 else {
                fatalError("history archive schema envelope failed")
            }

            let csvURL = try store.saveFullSamplesCSV(for: session)
            let relativePath = store.relativeCSVPath(for: csvURL)
            var csvSummary = summary
            csvSummary.fullSampleCSVPath = "/moved-user/Session CSV/\(csvURL.lastPathComponent)"
            csvSummary.fullSampleCSVRelativePath = relativePath
            csvSummary.fullSampleCSVSampleCount = session.samples.count
            guard relativePath == "Session CSV/\(csvURL.lastPathComponent)",
                  store.fullSamplesCSVURL(for: csvSummary)?.standardizedFileURL == csvURL.standardizedFileURL else {
                fatalError("relative CSV reference must resolve inside Application Support")
            }
            let fullExportURL = root.appendingPathComponent("full-export.csv")
            guard try store.copyFullSamplesCSV(for: csvSummary, to: fullExportURL) == .fullSamples else {
                fatalError("an existing full CSV must export as full samples")
            }

            try "outside\n".write(to: outsideURL, atomically: true, encoding: .utf8)
            var escapedSummary = summary
            escapedSummary.fullSampleCSVRelativePath = "../\(outsideURL.lastPathComponent)"
            escapedSummary.fullSampleCSVPath = outsideURL.path
            guard store.fullSamplesCSVURL(for: escapedSummary) == nil else {
                fatalError("history CSV references must not escape Application Support")
            }
            let fallbackExportURL = root.appendingPathComponent("fallback-export.csv")
            guard try store.copyFullSamplesCSV(for: escapedSummary, to: fallbackExportURL) == .archivedCurveSamples,
                  fileManager.fileExists(atPath: fallbackExportURL.path) else {
                fatalError("missing or unsafe full CSV references must export only archived curve samples")
            }

            let orphanURL = store.sessionCSVDirectoryURL.appendingPathComponent("orphan.csv")
            try "capturedAt\n".write(to: orphanURL, atomically: true, encoding: .utf8)
            let audit = try store.auditCSVArchive(referencedBy: [csvSummary])
            guard audit.referencedFileCount == 1,
                  audit.orphanedFiles.map(\.lastPathComponent) == ["orphan.csv"] else {
                fatalError("CSV archive audit must identify unreferenced files without deleting them")
            }

            try store.saveSessions([csvSummary])
            try Data("{broken-history".utf8).write(to: store.sessionsURL, options: [.atomic])
            let recovered = try store.loadSessions()
            guard recovered.count == 1,
                  store.lastRecoveryNotice != nil,
                  fileManager.fileExists(atPath: store.sessionsURL.path) else {
                fatalError("history corruption must recover from a rolling backup")
            }
            let recoveredFiles = try fileManager.contentsOfDirectory(at: store.corruptHistoryDirectoryURL, includingPropertiesForKeys: nil)
            guard recoveredFiles.contains(where: { $0.lastPathComponent.contains("corrupt") }) else {
                fatalError("corrupt primary history must be preserved for diagnosis")
            }
        } catch {
            fatalError("history archive self test failed: \(error.localizedDescription)")
        }
    }

    private static func powerSample(at date: Date, watts: Double) -> TelemetrySample {
        TelemetrySample(
            capturedAt: date,
            source: .powermetrics,
            sourceDetail: "test powermetrics",
            thermalState: "Nominal",
            thermalPressure: "nominal",
            cpuPowerW: watts * 0.65,
            gpuPowerW: watts * 0.3,
            anePowerW: nil,
            packagePowerW: watts,
            cpuActivePercent: 95,
            gpuActivePercent: 90,
            eClusterFrequencyMHz: 2100,
            pClusterFrequencyMHz: 3200,
            gpuFrequencyMHz: 1300,
            cpuTemperatureC: 70,
            gpuTemperatureC: 65,
            socTemperatureC: 68,
            powerSource: .unknown,
            isDegraded: false,
            message: nil
        )
    }
}
