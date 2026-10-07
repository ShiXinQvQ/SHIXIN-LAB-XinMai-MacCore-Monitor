// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import Darwin
import Foundation
import IOKit.ps

public actor TelemetrySampler {
    private let intervalMilliseconds: Int
    private var lastCPUActivitySnapshot = CPUActivityReader.readSnapshot()

    public init(intervalMilliseconds: Int = 500) {
        self.intervalMilliseconds = intervalMilliseconds
    }

    public func sample(preferHelper: Bool = true) async -> TelemetrySample {
        var helperFailure: Error?
        if preferHelper {
            do {
                var sample = try HelperSocketClient.sample()
                // A connected Helper may still be serving an expired idle cache.
                // Use the existing local read-only path instead of presenting old
                // power/frequency values or withholding fresh local temperatures.
                if let age = sample.helperSampleAgeSeconds, age > 2 {
                    // Keep the user-facing failure stable. Embedding the cache age
                    // here republishes AppState every poll even on non-live pages.
                    throw HelperSocketError.helperReturnedError(
                        "Helper 采样已过期，等待后台采样恢复。"
                    )
                }
                applyKernelCPUActivity(to: &sample)
                Self.applyLocalStorageTemperature(StorageTemperatureReader.cachedReading(), to: &sample)
                return sample
            } catch {
                helperFailure = error
            }
        }

        let powerSource = PowerSourceReader.read()
        let thermalState = ThermalStateReader.current()
        let hidTemperatures = HIDTemperatureReader.read()
        // The app never waits on a disk query; a one-shot root sample (the
        // Helper's --sample diagnostic) has no later poll to pick up a refresh.
        let storageTemperature = geteuid() == 0
            ? StorageTemperatureReader.read()
            : StorageTemperatureReader.cachedReading()

        guard geteuid() == 0 else {
            let helperMessage = helperFailure.map { "Helper 不可用：\($0.localizedDescription)。" } ?? ""
            var sample = TelemetrySample(
                capturedAt: Date(),
                source: .fallback,
                sourceDetail: "当前进程不是 root，powermetrics 已降级",
                thermalState: thermalState,
                thermalPressure: nil,
                cpuPowerW: nil,
                gpuPowerW: nil,
                anePowerW: nil,
                packagePowerW: nil,
                cpuActivePercent: nil,
                gpuActivePercent: nil,
                eClusterFrequencyMHz: nil,
                pClusterFrequencyMHz: nil,
                gpuFrequencyMHz: nil,
                cpuTemperatureC: hidTemperatures.cpuTemperatureC,
                gpuTemperatureC: hidTemperatures.gpuTemperatureC,
                socTemperatureC: hidTemperatures.socTemperatureC,
                powerSource: powerSource,
                isDegraded: true,
                message: degradedMessage(helperMessage: helperMessage, hidTemperatures: hidTemperatures),
                temperatureSourceDetail: hidTemperatures.sourceDetail,
                cpuTemperatureSensorCount: hidTemperatures.cpuSensorCount,
                gpuTemperatureSensorCount: hidTemperatures.gpuSensorCount,
                socTemperatureSensorCount: hidTemperatures.socSensorCount,
                fanRPMs: hidTemperatures.fanRPMs,
                ssdTemperatureC: hidTemperatures.ssdTemperatureC,
                diskTemperatureC: storageTemperature.diskTemperatureC,
                diskTemperatureSourceDetail: storageTemperature.sourceDetail,
                wifiTemperatureC: hidTemperatures.wifiTemperatureC,
                airflowTemperatureC: hidTemperatures.airflowTemperatureC,
                ambientTemperatureC: hidTemperatures.ambientTemperatureC
            )
            applyKernelCPUActivity(to: &sample)
            return sample
        }

        do {
            let output = try PowermetricsCommand.runOneSample(intervalMilliseconds: intervalMilliseconds)
            var sample = try PowermetricsParser.parse(
                output: output.stdout,
                fallbackThermalState: thermalState,
                powerSource: powerSource,
                sampleIntervalSeconds: Double(intervalMilliseconds) / 1000
            )
            mergeHIDTemperatures(hidTemperatures, into: &sample)
            applyKernelCPUActivity(to: &sample)
            if !output.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sample.message = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return sample
        } catch {
            var sample = TelemetrySample(
                capturedAt: Date(),
                source: .fallback,
                sourceDetail: "powermetrics 读取失败",
                thermalState: thermalState,
                thermalPressure: nil,
                cpuPowerW: nil,
                gpuPowerW: nil,
                anePowerW: nil,
                packagePowerW: nil,
                cpuActivePercent: nil,
                gpuActivePercent: nil,
                eClusterFrequencyMHz: nil,
                pClusterFrequencyMHz: nil,
                gpuFrequencyMHz: nil,
                cpuTemperatureC: hidTemperatures.cpuTemperatureC,
                gpuTemperatureC: hidTemperatures.gpuTemperatureC,
                socTemperatureC: hidTemperatures.socTemperatureC,
                powerSource: powerSource,
                isDegraded: true,
                message: "\(error.localizedDescription)\n\(hidTemperatures.sourceDetail)",
                temperatureSourceDetail: hidTemperatures.sourceDetail,
                cpuTemperatureSensorCount: hidTemperatures.cpuSensorCount,
                gpuTemperatureSensorCount: hidTemperatures.gpuSensorCount,
                socTemperatureSensorCount: hidTemperatures.socSensorCount,
                fanRPMs: hidTemperatures.fanRPMs,
                ssdTemperatureC: hidTemperatures.ssdTemperatureC,
                diskTemperatureC: storageTemperature.diskTemperatureC,
                diskTemperatureSourceDetail: storageTemperature.sourceDetail,
                wifiTemperatureC: hidTemperatures.wifiTemperatureC,
                airflowTemperatureC: hidTemperatures.airflowTemperatureC,
                ambientTemperatureC: hidTemperatures.ambientTemperatureC
            )
            applyKernelCPUActivity(to: &sample)
            return sample
        }
    }

    private func degradedMessage(helperMessage: String, hidTemperatures: HIDTemperatureSnapshot) -> String {
        var parts: [String] = []
        if !helperMessage.isEmpty {
            parts.append(helperMessage)
        }
        parts.append("powermetrics 需要管理员/root 权限。压力测试仍可运行；CPU/GPU 功耗与频率会降级，整机功耗独立读取。")
        if hidTemperatures.cpuTemperatureC != nil || hidTemperatures.gpuTemperatureC != nil {
            parts.append("CPU/GPU 温度已尝试从 \(hidTemperatures.sourceDetail) 读取。")
        } else if hidTemperatures.socTemperatureC != nil {
            parts.append("未匹配独立 CPU/GPU 温度；已使用 \(hidTemperatures.sourceDetail) 显示芯片热趋势。")
        } else {
            parts.append("温度也未匹配到可用 CPU/GPU/SoC 传感器。")
        }
        return parts.joined(separator: " ")
    }

    private func mergeHIDTemperatures(_ hidTemperatures: HIDTemperatureSnapshot, into sample: inout TelemetrySample) {
        if let cpuTemperature = hidTemperatures.cpuTemperatureC {
            sample.cpuTemperatureC = cpuTemperature
        }
        if let gpuTemperature = hidTemperatures.gpuTemperatureC {
            sample.gpuTemperatureC = gpuTemperature
        }
        if let socTemperature = hidTemperatures.socTemperatureC {
            sample.socTemperatureC = socTemperature
        }
        if hidTemperatures.hasAnyTemperature {
            sample.temperatureSourceDetail = hidTemperatures.sourceDetail
            sample.cpuTemperatureSensorCount = hidTemperatures.cpuSensorCount
            sample.gpuTemperatureSensorCount = hidTemperatures.gpuSensorCount
            sample.socTemperatureSensorCount = hidTemperatures.socSensorCount
        } else if sample.cpuTemperatureC != nil || sample.gpuTemperatureC != nil || sample.socTemperatureC != nil {
            sample.temperatureSourceDetail = "powermetrics plist 温度字段"
        } else {
            sample.temperatureSourceDetail = hidTemperatures.sourceDetail
            sample.cpuTemperatureSensorCount = 0
            sample.gpuTemperatureSensorCount = 0
            sample.socTemperatureSensorCount = 0
        }
        sample.fanRPMs = hidTemperatures.fanRPMs
        sample.ssdTemperatureC = hidTemperatures.ssdTemperatureC
        let storageTemperature = StorageTemperatureReader.read()
        sample.diskTemperatureC = storageTemperature.diskTemperatureC
        sample.diskTemperatureSourceDetail = storageTemperature.sourceDetail
        sample.wifiTemperatureC = hidTemperatures.wifiTemperatureC
        sample.airflowTemperatureC = hidTemperatures.airflowTemperatureC
        sample.ambientTemperatureC = hidTemperatures.ambientTemperatureC
    }

    /// The app reads the disk temperature itself; it needs no root privileges.
    /// A local reading wins. A reading from an older Helper is kept only while
    /// the app has none of its own yet.
    static func applyLocalStorageTemperature(_ storage: StorageTemperatureSnapshot, to sample: inout TelemetrySample) {
        guard storage.diskTemperatureC != nil || sample.diskTemperatureC == nil else { return }
        sample.diskTemperatureC = storage.diskTemperatureC
        sample.diskTemperatureSourceDetail = storage.sourceDetail
    }

    private func applyKernelCPUActivity(to sample: inout TelemetrySample) {
        // Read independently even when powermetrics/Helper is unavailable.
        sample.systemPower = SystemPowerReader.read()
        // powermetrics CPU residency and whole-machine kernel CPU utilisation
        // are different quantities. Missing ticks must not leak the former
        // (often 100%) into the latter's chart.
        sample.cpuActivePercent = nil
        guard let current = CPUActivityReader.readSnapshot() else { return }
        defer { lastCPUActivitySnapshot = current }
        guard let previous = lastCPUActivitySnapshot,
              let percent = CPUActivityReader.activePercent(from: previous, to: current) else {
            return
        }
        sample.cpuActivePercent = percent
    }
}

public struct CPUActivitySnapshot: Equatable {
    public var user: UInt64
    public var system: UInt64
    public var idle: UInt64
    public var nice: UInt64

    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

public enum CPUActivityReader {
    public static func readSnapshot() -> CPUActivitySnapshot? {
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27 {
            return readProcessorSnapshot()
        }
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_CPU_LOAD_INFO, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        return CPUActivitySnapshot(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }

    private static func readProcessorSnapshot() -> CPUActivitySnapshot? {
        // On macOS 27 host_statistics64 repeats cached aggregate counters across
        // several 250 ms polls. Per-processor counters retain the same metric
        // while advancing at our sampling cadence. Release the Mach allocation.
        var count: mach_msg_type_number_t = 0
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                  &cpuCount, &info, &count) == KERN_SUCCESS,
              let info else { return nil }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)),
                          vm_size_t(count) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
        guard count >= cpuCount * natural_t(CPU_STATE_MAX) else { return nil }
        var ticks = [UInt64](repeating: 0, count: Int(CPU_STATE_MAX))
        for cpu in 0..<Int(cpuCount) {
            for state in 0..<Int(CPU_STATE_MAX) {
                ticks[state] += UInt64(UInt32(bitPattern: info[cpu * Int(CPU_STATE_MAX) + state]))
            }
        }
        return CPUActivitySnapshot(user: ticks[Int(CPU_STATE_USER)],
                                   system: ticks[Int(CPU_STATE_SYSTEM)],
                                   idle: ticks[Int(CPU_STATE_IDLE)],
                                   nice: ticks[Int(CPU_STATE_NICE)])
    }

    public static func activePercent(from previous: CPUActivitySnapshot, to current: CPUActivitySnapshot) -> Double? {
        guard current.user >= previous.user,
              current.system >= previous.system,
              current.idle >= previous.idle,
              current.nice >= previous.nice else {
            return nil
        }

        let user = current.user - previous.user
        let system = current.system - previous.system
        let idle = current.idle - previous.idle
        let nice = current.nice - previous.nice
        let total = user + system + idle + nice
        guard total > 0 else { return nil }

        let active = user + system + nice
        return max(0, min(100, Double(active) / Double(total) * 100))
    }
}

public enum ThermalStateReader {
    public static func current() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: "Nominal"
        case .fair: "Fair"
        case .serious: "Serious"
        case .critical: "Critical"
        @unknown default: "Unknown"
        }
    }
}

enum PowermetricsCommand {
    struct Output {
        var stdout: Data
        var stderr: String
    }

    static func runOneSample(intervalMilliseconds: Int) throws -> Output {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/powermetrics")
        process.arguments = [
            "-n", "1",
            "-i", String(intervalMilliseconds),
            "--samplers", "cpu_power,gpu_power,thermal,ane_power",
            "--show-extra-power-info",
            "--handle-invalid-values",
            "-f", "plist"
        ]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        let timeout = max(3, Double(intervalMilliseconds) / 1000 + 2)
        guard waitForProcess(process, timeout: timeout) else {
            process.terminate()
            if !waitForProcess(process, timeout: 0.5), process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            throw TelemetryError.powermetricsFailed("powermetrics 超过 \(String(format: "%.1f", timeout)) 秒未返回")
        }

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        let errText = String(data: errData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw TelemetryError.powermetricsFailed(errText.isEmpty ? "powermetrics exit \(process.terminationStatus)" : errText)
        }
        guard !outData.isEmpty else {
            throw TelemetryError.powermetricsFailed("powermetrics 没有返回 plist 数据")
        }
        return Output(stdout: outData, stderr: errText)
    }

    private static func waitForProcess(_ process: Process, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        return !process.isRunning
    }
}

public enum PowermetricsParser {
    public static func parse(
        output: Data,
        fallbackThermalState: String,
        powerSource: PowerSourceSnapshot,
        sampleIntervalSeconds: TimeInterval? = nil
    ) throws -> TelemetrySample {
        let chunks = output.split(separator: 0).filter { !$0.isEmpty }
        guard let last = chunks.last else {
            throw TelemetryError.parseFailed("powermetrics plist 输出为空")
        }

        let plist = try PropertyListSerialization.propertyList(from: Data(last), options: [], format: nil)
        guard let root = plist as? [String: Any] else {
            throw TelemetryError.parseFailed("powermetrics plist 顶层不是字典")
        }

        let processor = root["processor"] as? [String: Any]
        let gpu = root["gpu"] as? [String: Any]
        let thermalPressure = root["thermal_pressure"] as? String
        let timestamp = (root["timestamp"] as? Date) ?? Date()

        let cpuPowerW = watts(fromMilliwatts: processor?["cpu_power"] ?? root["cpu_power"])
            ?? watts(fromMillijoules: processor?["cpu_energy"] ?? root["cpu_energy"], intervalSeconds: sampleIntervalSeconds)
        let gpuPowerW = watts(fromMilliwatts: processor?["gpu_power"] ?? root["gpu_power"])
            ?? watts(fromMillijoules: processor?["gpu_energy"] ?? root["gpu_energy"], intervalSeconds: sampleIntervalSeconds)
        let anePowerW = watts(fromMilliwatts: processor?["ane_power"] ?? root["ane_power"])
            ?? watts(fromMillijoules: processor?["ane_energy"] ?? root["ane_energy"], intervalSeconds: sampleIntervalSeconds)
        let packagePowerW = watts(fromMilliwatts: processor?["combined_power"] ?? root["combined_power"])
            ?? watts(fromMilliwatts: processor?["package_power"] ?? root["package_power"])

        let clusters = processor?["clusters"] as? [[String: Any]] ?? []
        let eClusters = clusters.filter { ($0["name"] as? String)?.uppercased().hasPrefix("E") == true }
        let pClusters = clusters.filter { ($0["name"] as? String)?.uppercased().hasPrefix("P") == true }

        let eFrequency = averageFrequencyMHz(for: eClusters)
        let pFrequency = averageFrequencyMHz(for: pClusters)
        let eActive = averageActivePercent(for: eClusters)
        let pActive = averageActivePercent(for: pClusters)
        let cpuActive = [eActive, pActive].compactMap { $0 }.average()

        let gpuFrequencyMHz = frequencyToMHz(gpu?["freq_hz"])
        let gpuActive = activePercent(idleRatioValue: gpu?["idle_ratio"])

        let allTemperatureValues = findNumbers(in: root, matching: { key in
            let lower = key.lowercased()
            return lower.contains("temperature") || lower.contains("temp")
        })
        let cpuTemperature = findNumbers(in: root, matching: { key in
            let lower = key.lowercased()
            return lower.contains("cpu") && (lower.contains("temperature") || lower.contains("temp"))
        }).average() ?? allTemperatureValues.average()
        let gpuTemperature = findNumbers(in: root, matching: { key in
            let lower = key.lowercased()
            return lower.contains("gpu") && (lower.contains("temperature") || lower.contains("temp"))
        }).average()

        return TelemetrySample(
            capturedAt: timestamp,
            source: .powermetrics,
            sourceDetail: "powermetrics plist / root direct",
            thermalState: fallbackThermalState,
            thermalPressure: thermalPressure,
            cpuPowerW: cpuPowerW,
            gpuPowerW: gpuPowerW,
            anePowerW: anePowerW,
            packagePowerW: packagePowerW,
            cpuActivePercent: cpuActive,
            gpuActivePercent: gpuActive,
            eClusterFrequencyMHz: eFrequency,
            pClusterFrequencyMHz: pFrequency,
            gpuFrequencyMHz: gpuFrequencyMHz,
            cpuTemperatureC: sanitizeTemperature(cpuTemperature),
            gpuTemperatureC: sanitizeTemperature(gpuTemperature),
            socTemperatureC: nil,
            powerSource: powerSource,
            isDegraded: false,
            message: nil,
            temperatureSourceDetail: (sanitizeTemperature(cpuTemperature) != nil || sanitizeTemperature(gpuTemperature) != nil) ? "powermetrics plist 温度字段" : nil,
            cpuTemperatureSensorCount: nil,
            gpuTemperatureSensorCount: nil,
            samplingIntervalMilliseconds: sampleIntervalSeconds.map { Int(($0 * 1000).rounded()) }
        )
    }

    private static func watts(fromMilliwatts value: Any?) -> Double? {
        guard let number = double(value) else { return nil }
        return number / 1000
    }

    private static func watts(fromMillijoules value: Any?, intervalSeconds: TimeInterval?) -> Double? {
        guard let number = double(value),
              let intervalSeconds,
              intervalSeconds.isFinite,
              intervalSeconds > 0 else {
            return nil
        }
        return number / intervalSeconds / 1000
    }

    private static func frequencyToMHz(_ value: Any?) -> Double? {
        guard let number = double(value) else { return nil }
        if number > 1_000_000 {
            return number / 1_000_000
        }
        if number > 10_000 {
            return number / 1_000
        }
        return number
    }

    private static func activePercent(idleRatioValue: Any?) -> Double? {
        guard let idle = double(idleRatioValue) else { return nil }
        return max(0, min(100, (1 - idle) * 100))
    }

    private static func averageFrequencyMHz(for clusters: [[String: Any]]) -> Double? {
        clusters.compactMap { frequencyToMHz($0["freq_hz"]) }.average()
    }

    private static func averageActivePercent(for clusters: [[String: Any]]) -> Double? {
        clusters.compactMap { activePercent(idleRatioValue: $0["idle_ratio"]) }.average()
    }

    private static func sanitizeTemperature(_ value: Double?) -> Double? {
        guard let value, value > 0, value < 140 else { return nil }
        return value
    }

    private static func findNumbers(in value: Any, matching predicate: (String) -> Bool) -> [Double] {
        var results: [Double] = []
        walk(value, key: "", predicate: predicate, results: &results)
        return results
    }

    private static func walk(_ value: Any, key: String, predicate: (String) -> Bool, results: inout [Double]) {
        if predicate(key), let number = double(value) {
            results.append(number)
            return
        }

        if let dictionary = value as? [String: Any] {
            for (childKey, childValue) in dictionary {
                walk(childValue, key: childKey, predicate: predicate, results: &results)
            }
        } else if let array = value as? [Any] {
            for child in array {
                walk(child, key: key, predicate: predicate, results: &results)
            }
        }
    }

    private static func double(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Float { return Double(value) }
        if let value = value as? Int { return Double(value) }
        if let value = value as? Int64 { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }
}

enum PowerSourceReader {
    private static let cacheLock = NSLock()
    private static var cached: (date: Date, snapshot: PowerSourceSnapshot)?
    private static let cacheLifetime: TimeInterval = 5

    static func read() -> PowerSourceSnapshot {
        cacheLock.lock()
        if let cached, Date().timeIntervalSince(cached.date) < cacheLifetime {
            cacheLock.unlock()
            return cached.snapshot
        }
        cacheLock.unlock()

        let snapshot = readUncached()
        cacheLock.lock()
        cached = (Date(), snapshot)
        cacheLock.unlock()
        return snapshot
    }

    private static func readUncached() -> PowerSourceSnapshot {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return .unknown
        }
        let providingType = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        var descriptions: [[String: Any]] = []
        if let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                if let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] {
                    descriptions.append(description)
                }
            }
        }
        return snapshot(providingType: providingType, sources: descriptions)
    }

    /// Maps IOKit power-source data (key names from IOPSKeys.h) to the snapshot
    /// the app shows. Reading IOKit directly replaces launching `pmset`, so the
    /// Helper starts no short-lived child processes while it samples.
    static func snapshot(providingType: String?, sources: [[String: Any]]) -> PowerSourceSnapshot {
        let source: String
        switch providingType {
        case "AC Power":
            source = "电源适配器"
        case "Battery Power":
            source = "电池"
        default:
            source = "未知"
        }

        let battery = sources.first { ($0["Type"] as? String) == "InternalBattery" }
        var percent: Int?
        if let battery,
           let current = (battery["Current Capacity"] as? NSNumber)?.doubleValue,
           let maximum = (battery["Max Capacity"] as? NSNumber)?.doubleValue,
           maximum > 0 {
            percent = Int((current / maximum * 100).rounded())
        }
        let charging = (battery?["Is Charging"] as? Bool) ?? false
        return PowerSourceSnapshot(source: source, batteryPercent: percent, isCharging: charging, adapterWatts: nil)
    }
}

enum TelemetryError: LocalizedError {
    case powermetricsFailed(String)
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .powermetricsFailed(let message):
            return "powermetrics 采样失败：\(message.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .parseFailed(let message):
            return "powermetrics 解析失败：\(message)"
        }
    }
}

extension Array where Element == Double {
    func average() -> Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
