import Foundation

public struct TemperatureDiagnosticsSnapshot: Codable, Equatable {
    public var cpuSensorCount: Int
    public var gpuSensorCount: Int
    public var socSensorCount: Int
    public var allSensorCount: Int
    public var fanCount: Int
    public var sourceDetail: String
    public var cpuTemperatureC: Double?
    public var gpuTemperatureC: Double?
    public var socTemperatureC: Double?

    public init(
        cpuSensorCount: Int,
        gpuSensorCount: Int,
        socSensorCount: Int,
        allSensorCount: Int,
        fanCount: Int,
        sourceDetail: String,
        cpuTemperatureC: Double?,
        gpuTemperatureC: Double?,
        socTemperatureC: Double?
    ) {
        self.cpuSensorCount = cpuSensorCount
        self.gpuSensorCount = gpuSensorCount
        self.socSensorCount = socSensorCount
        self.allSensorCount = allSensorCount
        self.fanCount = fanCount
        self.sourceDetail = sourceDetail
        self.cpuTemperatureC = cpuTemperatureC
        self.gpuTemperatureC = gpuTemperatureC
        self.socTemperatureC = socTemperatureC
    }
}

public enum HardwareDiagnostics {
    public static func temperatureDebugSummary() -> String {
        SMCTemperatureReader.debugSummary()
    }

    public static func temperatureSnapshot() -> TemperatureDiagnosticsSnapshot {
        let snapshot = HIDTemperatureReader.read()
        return TemperatureDiagnosticsSnapshot(
            cpuSensorCount: snapshot.cpuSensorCount,
            gpuSensorCount: snapshot.gpuSensorCount,
            socSensorCount: snapshot.socSensorCount,
            allSensorCount: snapshot.allSensorCount,
            fanCount: snapshot.fanRPMs.count,
            sourceDetail: snapshot.sourceDetail,
            cpuTemperatureC: snapshot.cpuTemperatureC,
            gpuTemperatureC: snapshot.gpuTemperatureC,
            socTemperatureC: snapshot.socTemperatureC
        )
    }
}
