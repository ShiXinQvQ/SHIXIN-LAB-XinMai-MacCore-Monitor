// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum Formatters {
    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()

    public static func time(_ date: Date) -> String {
        shortTimeFormatter.string(from: date)
    }

    public static func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    public static func logDate(_ date: Date) -> String {
        shortTimeFormatter.string(from: date)
    }

    public static func watts(_ value: Double?) -> String {
        guard let value else { return "不可用" }
        return String(format: "%.1f W", value)
    }

    public static func percent(_ value: Double?) -> String {
        guard let value else { return "不可用" }
        return String(format: "%.0f%%", value)
    }

    public static func mhz(_ value: Double?) -> String {
        guard let value else { return "不可用" }
        return String(format: "%.0f MHz", value)
    }

    public static func ghzFromMHz(_ value: Double?) -> String {
        guard let value else { return "不可用" }
        return String(format: "%.2f GHz", value / 1000)
    }

    public static func celsius(_ value: Double?) -> String {
        guard let value else { return "降级不可用" }
        return String(format: "%.1f °C", value)
    }

    public static func rpm(_ value: Double?) -> String {
        guard let value else { return "不可用" }
        return String(format: "%.0f RPM", value)
    }

    public static func rpmCompact(_ value: Double?) -> String {
        guard let value else { return "不可用" }
        if abs(value) >= 1000 {
            return String(format: "%.1fk rpm", value / 1000)
        }
        return String(format: "%.0f rpm", value)
    }

    public static func bytes(_ value: UInt64?) -> String {
        guard let value else { return "不可用" }
        let units = ["B", "KB", "MB", "GB", "TB"]
        var number = Double(value)
        var unitIndex = 0
        while number >= 1024, unitIndex < units.count - 1 {
            number /= 1024
            unitIndex += 1
        }
        if unitIndex == 0 {
            return "\(Int(number)) \(units[unitIndex])"
        }
        return String(format: "%.1f %@", number, units[unitIndex])
    }

    public static func seconds(_ value: TimeInterval) -> String {
        let total = max(0, Int(value.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public static func wh(_ value: Double?) -> String {
        guard let value else { return "不可用" }
        return String(format: "%.2f Wh", value)
    }
}
