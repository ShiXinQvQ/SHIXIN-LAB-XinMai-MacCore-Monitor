// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import CryptoKit
import Foundation
import ShixinStressPowerCore

struct HelperInstallStatus: Equatable {
    var helperExists: Bool
    var plistExists: Bool
    var launchdLoaded: Bool
    var socketReachable: Bool
    var helperVersion: String?
    var versionMatches: Bool
    var bundledBinaryMatches: Bool?
    var samplingState: String?
    var sampleAgeSeconds: TimeInterval?
    var detail: String

    var isOperational: Bool {
        let serviceAvailable = helperExists && plistExists && launchdLoaded && socketReachable
        guard serviceAvailable else { return false }
        guard let samplingState else { return true }
        if samplingState == "idle" { return true }
        return samplingState == "ready" && (sampleAgeSeconds ?? .infinity) <= 2
    }

    var isUsable: Bool {
        isOperational && versionMatches && bundledBinaryMatches != false
    }

    var needsUpdate: Bool {
        let serviceAvailable = helperExists && plistExists && launchdLoaded && socketReachable
        return serviceAvailable && (!versionMatches || bundledBinaryMatches == false)
    }

    var title: String {
        if isUsable { return "Helper 已安装并可用" }
        if needsUpdate { return "Helper 需要更新" }
        if versionMatches, socketReachable { return "Helper 采样流正在恢复" }
        if helperExists || plistExists || launchdLoaded { return "Helper 已安装但未完全可用" }
        return "Helper 未安装"
    }
}

enum HelperInstallManager {
    static func status() -> HelperInstallStatus {
        let helperExists = FileManager.default.isExecutableFile(atPath: HelperConstants.installedHelperPath)
        let plistExists = FileManager.default.fileExists(atPath: HelperConstants.launchDaemonPath)
        let launchdLoaded = launchctlPrintLoaded()
        let helperInfo = try? HelperSocketClient.info()
        let socketReachable = helperInfo != nil
        let helperVersion = helperInfo?.helperVersion
        let versionMatches = helperVersion == HelperConstants.helperVersion
        let bundledBinaryMatches = installedBinaryMatchesBundled()
        let samplingState = helperInfo?.samplingHealth?.state
        let sampleAgeSeconds = helperInfo?.samplingHealth?.sampleAgeSeconds
        let samplingDetail: String
        if let samplingState {
            let age = samplingState == "idle"
                ? L10n.t("按需待机")
                : sampleAgeSeconds.map { String(format: L10n.t("%.1f 秒"), $0) } ?? L10n.t("等待首样本")
            samplingDetail = String(format: L10n.t("采样流 %@ / %@"), samplingState, age)
        } else {
            samplingDetail = L10n.t("采样流状态未知")
        }
        let detail = [
            L10n.t(helperExists ? "二进制存在" : "二进制缺失"),
            L10n.t(plistExists ? "LaunchDaemon plist 存在" : "LaunchDaemon plist 缺失"),
            L10n.t(launchdLoaded ? "launchd 已加载" : "launchd 未加载"),
            L10n.t(socketReachable ? "socket 可连接" : "socket 不可连接"),
            String(
                format: L10n.t("版本 %@ / 需要 %@"),
                helperVersion ?? L10n.t("未知"),
                HelperConstants.helperVersion
            ),
            binaryMatchDetail(bundledBinaryMatches),
            samplingDetail
        ].joined(separator: " · ")
        return HelperInstallStatus(
            helperExists: helperExists,
            plistExists: plistExists,
            launchdLoaded: launchdLoaded,
            socketReachable: socketReachable,
            helperVersion: helperVersion,
            versionMatches: versionMatches,
            bundledBinaryMatches: bundledBinaryMatches,
            samplingState: samplingState,
            sampleAgeSeconds: sampleAgeSeconds,
            detail: detail
        )
    }

    static func install() throws {
        guard let helperURL = bundledHelperURL(),
              FileManager.default.isExecutableFile(atPath: helperURL.path) else {
            throw HelperInstallError.bundledHelperMissing
        }

        let script = installScript(helperURL: helperURL)
        try runWithAdministratorPrivileges(script)
        try waitForExpectedHelperVersion()
    }

    static func uninstall() throws {
        try runWithAdministratorPrivileges(uninstallScript())
    }

    static func repair() throws -> String {
        let currentStatus = status()
        if !currentStatus.helperExists
            || !currentStatus.plistExists
            || !currentStatus.versionMatches
            || currentStatus.bundledBinaryMatches == false {
            try install()
            return L10n.t("Helper 修复完成：已重新安装并验证版本与内置二进制。")
        }
        try restart()
        return L10n.t("Helper 修复完成：已重启服务并验证连接。")
    }

    static func restart() throws {
        let currentStatus = status()
        guard currentStatus.helperExists, currentStatus.plistExists else {
            try install()
            return
        }
        try runWithAdministratorPrivileges(restartScript())
        try waitForExpectedHelperVersion()
    }

    private static func bundledHelperURL() -> URL? {
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(HelperConstants.bundledHelperRelativePath),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(HelperConstants.bundledHelperRelativePath)")
        ].compactMap { $0 }
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func installScript(helperURL: URL) -> String {
        let source = shellQuote(helperURL.path)
        let helper = shellQuote(HelperConstants.installedHelperPath)
        let plist = shellQuote(HelperConstants.launchDaemonPath)
        let socket = shellQuote(HelperConstants.socketPath)
        return """
        set -e
        /bin/launchctl bootout system \(plist) >/dev/null 2>&1 || true
        /bin/rm -f \(socket)
        /bin/mkdir -p /Library/PrivilegedHelperTools
        /bin/cp \(source) \(helper)
        /usr/sbin/chown root:wheel \(helper)
        /bin/chmod 755 \(helper)
        /bin/cat > \(plist) <<'SHIXIN_HELPER_PLIST'
        \(HelperConstants.launchDaemonPlist)
        SHIXIN_HELPER_PLIST
        /usr/sbin/chown root:wheel \(plist)
        /bin/chmod 644 \(plist)
        /bin/launchctl bootstrap system \(plist)
        /bin/launchctl kickstart -k system/\(HelperConstants.label)
        """
    }

    private static func uninstallScript() -> String {
        let helper = shellQuote(HelperConstants.installedHelperPath)
        let plist = shellQuote(HelperConstants.launchDaemonPath)
        let socket = shellQuote(HelperConstants.socketPath)
        return """
        set -e
        /bin/launchctl bootout system \(plist) >/dev/null 2>&1 || true
        /bin/rm -f \(socket)
        /bin/rm -f \(plist)
        /bin/rm -f \(helper)
        """
    }

    private static func restartScript() -> String {
        let plist = shellQuote(HelperConstants.launchDaemonPath)
        let socket = shellQuote(HelperConstants.socketPath)
        return """
        set -e
        /bin/launchctl bootout system \(plist) >/dev/null 2>&1 || true
        /bin/rm -f \(socket)
        /bin/launchctl bootstrap system \(plist)
        /bin/launchctl kickstart -k system/\(HelperConstants.label)
        """
    }

    private static func runWithAdministratorPrivileges(_ script: String) throws {
        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("shixin-helper-\(UUID().uuidString).sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        let command = "/bin/sh \(shellQuote(scriptURL.path))"
        let appleScript = "do shell script \"\(appleScriptEscape(command))\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        let stderr = Pipe()
        process.standardError = stderr
        process.standardOutput = Pipe()
        try process.run()
        process.waitUntilExit()

        let errorText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw HelperInstallError.privilegedScriptFailed(errorText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func launchctlPrintLoaded() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["print", "system/\(HelperConstants.label)"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func waitForExpectedHelperVersion(timeoutSeconds: TimeInterval = 12) throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        var lastVersion: String?
        while Date() < deadline {
            if let info = try? HelperSocketClient.info() {
                lastVersion = info.helperVersion
                if info.helperVersion == HelperConstants.helperVersion,
                   info.samplingHealth?.state == "idle" {
                    _ = try? HelperSocketClient.sample()
                }
                let samplingReady = info.samplingHealth?.state == "ready"
                    && (info.samplingHealth?.sampleAgeSeconds ?? .infinity) <= 2
                if info.helperVersion == HelperConstants.helperVersion,
                   samplingReady,
                   installedBinaryMatchesBundled() == true {
                    return
                }
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
        if lastVersion == HelperConstants.helperVersion, installedBinaryMatchesBundled() != true {
            throw HelperInstallError.binaryVerificationFailed
        }
        throw HelperInstallError.versionVerificationFailed(current: lastVersion, expected: HelperConstants.helperVersion)
    }

    private static func installedBinaryMatchesBundled() -> Bool? {
        guard FileManager.default.isExecutableFile(atPath: HelperConstants.installedHelperPath),
              let bundledURL = bundledHelperURL(),
              let installedHash = sha256(URL(fileURLWithPath: HelperConstants.installedHelperPath)),
              let bundledHash = sha256(bundledURL) else {
            return nil
        }
        return installedHash == bundledHash
    }

    private static func sha256(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func binaryMatchDetail(_ matches: Bool?) -> String {
        switch matches {
        case true: L10n.t("二进制与 App 内置 Helper 一致")
        case false: L10n.t("二进制与 App 内置 Helper 不一致")
        case nil: L10n.t("内置 Helper 二进制暂无法比对")
        }
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func appleScriptEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

enum HelperInstallError: LocalizedError {
    case bundledHelperMissing
    case privilegedScriptFailed(String)
    case versionVerificationFailed(current: String?, expected: String)
    case binaryVerificationFailed

    var errorDescription: String? {
        switch self {
        case .bundledHelperMissing:
            return "App 包内没有找到可安装的 Helper。请先重新构建 .app。"
        case .privilegedScriptFailed(let message):
            return message.isEmpty ? "管理员安装脚本执行失败或用户取消授权。" : message
        case .versionVerificationFailed(let current, let expected):
            return "Helper 安装脚本已结束，但版本验证未通过：当前 \(current ?? "未知")，需要 \(expected)。请稍后刷新状态或重新安装。"
        case .binaryVerificationFailed:
            return L10n.t("Helper 版本号正确，但已安装二进制与当前 App 内置 Helper 不一致。请重新安装。")
        }
    }
}
