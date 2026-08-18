// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import ShixinStressPowerCore
import SwiftUI

enum L10n {
    static func t(_ key: String) -> String {
        let localized = NSLocalizedString(key, comment: "")
        if localized != key {
            return localized
        }
        return fallback(key)
    }

    private static func fallback(_ key: String) -> String {
        guard !isChineseInterface else { return key }
        return isJapaneseInterface ? japaneseFallback(key) : englishFallback(key)
    }

    private static var currentLanguageCode: String {
        if let preferred = UserDefaults.standard.array(forKey: "AppleLanguages")?.first as? String {
            return preferred.lowercased()
        }
        return Locale.preferredLanguages.first?.lowercased() ?? ""
    }

    private static var isChineseInterface: Bool {
        currentLanguageCode.hasPrefix("zh")
    }

    private static var isJapaneseInterface: Bool {
        currentLanguageCode.hasPrefix("ja")
    }

    private static func englishFallback(_ key: String) -> String {
        if let helperStatus = englishHelperStatus(key) {
            return helperStatus
        }
        if let exact = englishExact[key] {
            return exact
        }
        return applyDynamicReplacements(
            key,
            replacements: [
                ("开始 ", "Started "),
                (" 烤机，目标时长 ", " stress test · target "),
                ("启动失败：", "Start failed: "),
                ("Serious 热状态持续超过 ", "Serious thermal state lasted over "),
                (" 秒，自动停止。", " s; stopping automatically."),
                ("停止：", "Stopped: "),
                ("完整采样 CSV 已保存：", "Full-sample CSV saved: "),
                ("完整采样 CSV 保存失败：", "Failed to save full-sample CSV: "),
                ("历史记录读取失败：", "Failed to load history: "),
                ("删除历史失败：", "Failed to delete history: "),
                ("保存历史失败：", "Failed to save history: "),
                ("国际诊断历史读取失败：", "Failed to load international diagnostics history: "),
                ("国际诊断历史保存失败：", "Failed to save international diagnostics history: "),
                ("国际诊断失败：", "International diagnostics failed: "),
                ("服务暂时无法完成查询：", "The provider could not complete the query: "),
                ("服务结果缺少必要字段：", "The provider response is missing a required field: "),
                ("用户手动停止", "User stopped"),
                ("达到设定时长", "Duration reached"),
                ("系统热状态 Critical", "Thermal Critical"),
                ("系统热状态 Serious 持续过久", "Thermal Serious too long"),
                ("采样中断保护", "Sampling watchdog"),
                ("压力测试异常", "Stress-test error"),
                ("App 退出清理", "App exit cleanup"),
                ("powermetrics 常驻流", "powermetrics stream"),
                ("温度/风扇", "temperature/fans"),
                ("电源/硬盘", "power/disk"),
                ("App 本地补齐", "completed locally by App"),
                ("常驻采样流", "sampling stream"),
                ("超过 3 秒没有新数据", "has no new data for over 3 s"),
                ("读取失败", "read failed"),
                ("未产生有效样本", "produced no valid samples"),
                ("正在恢复", "is recovering"),
                ("已延迟", "is delayed"),
                ("活跃度 ", "Activity "),
                ("峰值 ", "Peak "),
                ("可用 ", "Free "),
                ("逻辑核心 ", "Logical "),
                (" 个传感器", " sensors"),
                (" 个风扇", " fans"),
                (" 个样本", " samples"),
                (" 内核", " cores"),
                (" 核心", " cores"),
                (" 性能 + ", " P + "),
                (" 能效", " E"),
                (" 效率", " E"),
                ("（", " ("),
                ("）", ")"),
                (" 秒", " s"),
                ("，", ", "),
                ("；", "; "),
                ("：", ": "),
                ("。", ".")
            ]
        )
    }

    private static func japaneseFallback(_ key: String) -> String {
        if let helperStatus = japaneseHelperStatus(key) {
            return helperStatus
        }
        if let exact = japaneseExact[key] {
            return exact
        }
        return applyDynamicReplacements(
            key,
            replacements: [
                ("开始 ", ""),
                (" 烤机，目标时长 ", "ストレステストを開始 · 目標 "),
                ("启动失败：", "開始失敗："),
                ("Serious 热状态持续超过 ", "Serious状態が "),
                (" 秒，自动停止。", " 秒を超えて継続したため、自動停止しました。"),
                ("停止：", "停止理由："),
                ("完整采样 CSV 已保存：", "全サンプルCSVを保存："),
                ("完整采样 CSV 保存失败：", "全サンプルCSVの保存に失敗："),
                ("历史记录读取失败：", "履歴の読み込みに失敗："),
                ("删除历史失败：", "履歴の削除に失敗："),
                ("保存历史失败：", "履歴の保存に失敗："),
                ("国际诊断历史读取失败：", "国際診断履歴の読み込みに失敗："),
                ("国际诊断历史保存失败：", "国際診断履歴の保存に失敗："),
                ("国际诊断失败：", "国際ネットワーク診断に失敗："),
                ("服务暂时无法完成查询：", "プロバイダーが照会を完了できません："),
                ("服务结果缺少必要字段：", "プロバイダー応答に必須項目がありません："),
                ("用户手动停止", "ユーザー停止"),
                ("达到设定时长", "時間到達"),
                ("系统热状态 Critical", "熱状態 Critical"),
                ("系统热状态 Serious 持续过久", "Serious 継続超過"),
                ("采样中断保护", "サンプル中断保護"),
                ("压力测试异常", "テスト異常"),
                ("App 退出清理", "App 終了処理"),
                ("powermetrics 常驻流", "powermetrics 常駐ストリーム"),
                ("温度/风扇", "温度/ファン"),
                ("电源/硬盘", "電源/ディスク"),
                ("App 本地补齐", "App がローカル補完"),
                ("常驻采样流", "常駐サンプリング"),
                ("超过 3 秒没有新数据", "は3秒以上新しいデータがありません"),
                ("读取失败", "読み取り失敗"),
                ("未产生有效样本", "有効なサンプルがありません"),
                ("正在恢复", "を復旧中"),
                ("已延迟", "が遅延"),
                ("活跃度 ", "アクティビティ "),
                ("峰值 ", "ピーク "),
                ("可用 ", "空き "),
                ("逻辑核心 ", "論理コア "),
                (" 个传感器", " センサー"),
                (" 个风扇", " ファン"),
                (" 个样本", " サンプル"),
                (" 内核", " コア"),
                (" 核心", " コア"),
                (" 性能 + ", " P + "),
                (" 能效", " E"),
                (" 效率", " E"),
                ("（", "（"),
                ("）", "）")
            ]
        )
    }

    private static func englishHelperStatus(_ key: String) -> String? {
        let delayedPrefix = "Helper 缓存样本已延迟 "
        let delayedSuffix = " 秒，常驻采样流正在恢复。"
        if key.hasPrefix(delayedPrefix), key.hasSuffix(delayedSuffix) {
            let age = key
                .dropFirst(delayedPrefix.count)
                .dropLast(delayedSuffix.count)
            return "Helper cached sample is \(age) s old; the sampling stream is recovering."
        }

        let recoveryPrefix = "Helper 常驻采样流正在恢复："
        if key.hasPrefix(recoveryPrefix) {
            let detail = String(key.dropFirst(recoveryPrefix.count))
            return "Helper sampling stream is recovering: \(englishFallback(detail))"
        }
        return nil
    }

    private static func japaneseHelperStatus(_ key: String) -> String? {
        let delayedPrefix = "Helper 缓存样本已延迟 "
        let delayedSuffix = " 秒，常驻采样流正在恢复。"
        if key.hasPrefix(delayedPrefix), key.hasSuffix(delayedSuffix) {
            let age = key
                .dropFirst(delayedPrefix.count)
                .dropLast(delayedSuffix.count)
            return "Helperのキャッシュサンプルは\(age)秒遅延しています。常駐サンプリングを復旧中です。"
        }

        let recoveryPrefix = "Helper 常驻采样流正在恢复："
        if key.hasPrefix(recoveryPrefix) {
            let detail = String(key.dropFirst(recoveryPrefix.count))
            return "Helperの常駐サンプリングを復旧中：\(japaneseFallback(detail))"
        }
        return nil
    }

    private static func applyDynamicReplacements(_ key: String, replacements: [(String, String)]) -> String {
        var result = key
        for (source, target) in replacements {
            result = result.replacingOccurrences(of: source, with: target)
        }
        return result
    }

    private static let englishExact: [String: String] = [
        "未知": "Unknown",
        "Helper 正在等待第一条 powermetrics 样本。": "Helper is waiting for the first powermetrics sample.",
        "未读取": "Not Read",
        "读取中": "Reading",
        "未公开": "Not Reported",
        "已连接": "Connected",
        "主显示器": "Main Display",
        "等待": "Waiting",
        "关闭": "Off",
        "关闭 / 0 RPM": "Off / 0 RPM",
        "充电中": "Charging",
        "电池": "Battery",
        "电源适配器": "Power Adapter",
        "统一内存": "Unified Memory",
        "核心分配未知": "Core split unknown",
        "未匹配 CPU/GPU/SoC": "No CPU/GPU/SoC match",
        "当前没有可用的 powermetrics 样本，采样中断保护暂未启用；热状态保护仍然有效。": "No valid powermetrics sample is available yet. The sampling watchdog is not armed; thermal-state protection remains active.",
        "检测到 Critical 热状态，自动停止。": "Critical thermal state detected; stopping automatically.",
        "热状态进入 Serious，开始保护计时。": "Thermal state entered Serious; protection timer started.",
        "powermetrics 有效采样中断超过 8 秒，触发保护停止。": "Valid powermetrics sampling was interrupted for over 8 s; safety stop triggered.",
        "AppleSMC + HID": "AppleSMC + HID"
    ]

    private static let japaneseExact: [String: String] = [
        "未知": "不明",
        "Helper 正在等待第一条 powermetrics 样本。": "Helperは最初のpowermetricsサンプルを待っています。",
        "未读取": "未取得",
        "读取中": "取得中",
        "未公开": "非公開",
        "已连接": "接続済み",
        "主显示器": "メインディスプレイ",
        "等待": "待機中",
        "关闭": "オフ",
        "关闭 / 0 RPM": "オフ / 0 RPM",
        "充电中": "充電中",
        "电池": "バッテリー",
        "电源适配器": "電源アダプタ",
        "统一内存": "ユニファイドメモリ",
        "核心分配未知": "コア構成不明",
        "未匹配 CPU/GPU/SoC": "CPU/GPU/SoC 未一致",
        "当前没有可用的 powermetrics 样本，采样中断保护暂未启用；热状态保护仍然有效。": "有効なpowermetricsサンプルがないため、サンプリング監視は未作動です。熱状態保護は引き続き有効です。",
        "检测到 Critical 热状态，自动停止。": "Critical熱状態を検出したため、自動停止しました。",
        "热状态进入 Serious，开始保护计时。": "Serious熱状態に入り、保護タイマーを開始しました。",
        "powermetrics 有效采样中断超过 8 秒，触发保护停止。": "有効なpowermetricsサンプリングが8秒以上途切れたため、安全停止しました。",
        "AppleSMC + HID": "AppleSMC + HID"
    ]
}

extension View {
    @ViewBuilder
    func labGlassCard(padding: CGFloat = 18, cornerRadius: CGFloat = 18) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        #if SHIXIN_LEGACY_SDK
        self
            .padding(padding)
            .background(.thinMaterial, in: shape)
            .overlay {
                shape.stroke(.white.opacity(0.08), lineWidth: 1)
            }
        #else
        if #available(macOS 26.0, *) {
            self
                .padding(padding)
                .background {
                    shape.fill(Color.white.opacity(0.035))
                }
                .glassEffect(.regular.tint(Color.white.opacity(0.04)), in: shape)
                .overlay {
                    shape.stroke(.white.opacity(0.12), lineWidth: 1)
                }
        } else {
            self
                .padding(padding)
                .background(.thinMaterial, in: shape)
                .overlay {
                    shape.stroke(.white.opacity(0.08), lineWidth: 1)
                }
        }
        #endif
    }

    func labSettingsCard(padding: CGFloat = 18, cornerRadius: CGFloat = 18) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .padding(padding)
            .background {
                shape.fill(Color(red: 0.125, green: 0.135, blue: 0.145))
            }
            .overlay {
                shape.stroke(Color.white.opacity(0.11), lineWidth: 1)
            }
    }
}

struct LabBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.03, green: 0.04, blue: 0.06),
                Color(red: 0.05, green: 0.07, blue: 0.10),
                Color(red: 0.02, green: 0.025, blue: 0.035)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct SectionHeader: View {
    var title: String
    var systemImage: String
    var help: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(L10n.t(title))
                .font(.headline)
                .lineLimit(1)
            if let help {
                InfoHelpButton(title: title, message: help)
            }
            Spacer()
        }
    }
}

struct StatusPill: View {
    var text: String
    var systemImage: String
    var tint: Color

    var body: some View {
        Label(L10n.t(text), systemImage: systemImage)
            .font(.caption.weight(.medium))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
            .overlay {
                Capsule().stroke(tint.opacity(0.22), lineWidth: 1)
            }
    }
}

struct InfoHelpButton: View {
    var title: String
    var message: String
    @State private var isPresented = false
    @State private var isPinned = false
    @State private var hoverToken = UUID()

    var body: some View {
        Button {
            isPinned.toggle()
            isPresented = isPinned
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(L10n.t(title))
        .onHover { hovering in
            updateHoverState(hovering)
        }
        .onChange(of: isPresented) { _, presented in
            if !presented {
                isPinned = false
            }
        }
        .popover(isPresented: $isPresented, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.t(title))
                    .font(.headline)
                Text(L10n.t(message))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(width: 320, alignment: .leading)
        }
        .accessibilityLabel(L10n.t(title))
        .accessibilityHint(L10n.t(message))
    }

    private func updateHoverState(_ hovering: Bool) {
        hoverToken = UUID()
        let token = hoverToken
        let delay: TimeInterval = hovering ? 0.18 : 0.28
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard hoverToken == token else { return }
            if hovering {
                isPresented = true
            } else if !isPinned {
                isPresented = false
            }
        }
    }
}

struct MetricTile: View {
    var title: String
    var value: String
    var detail: String?
    var systemImage: String
    var tint: Color
    var help: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                Spacer()
            }
            .frame(height: 22, alignment: .top)

            Text(L10n.t(value))
                .font(.system(size: 28, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .contentTransition(.numericText())
                .frame(height: 36, alignment: .bottomLeading)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(L10n.t(title))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if let effectiveHelp {
                        InfoHelpButton(title: title, message: effectiveHelp)
                    }
                }
                if let detail {
                    Text(L10n.t(detail))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .truncationMode(.tail)
                }
            }
            .frame(height: 36, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .labGlassCard(padding: 15, cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }

    private var effectiveHelp: String? {
        help ?? Self.defaultHelp(for: title)
    }

    private static func defaultHelp(for title: String) -> String? {
        switch title {
        case "总/包功耗":
            return "当前整机 SoC/封装侧功耗。优先使用 powermetrics 的 package power；如果系统只返回分项功耗，则用 CPU、GPU、ANE 等可读分项相加估算。"
        case "CPU 功耗":
            return "CPU 部分的实时功耗，来自 powermetrics。下方活跃度表示 CPU 在采样窗口内的忙碌比例，用来判断压力是否真正打满。"
        case "GPU 功耗":
            return "GPU 部分的实时功耗，来自 powermetrics。下方活跃度表示 Metal/图形相关 GPU 负载在采样窗口内的忙碌比例。"
        case "峰值功耗":
            return "当前窗口或本次 Session 里记录到的最高总功耗。瞬时峰值会高于长期稳定功耗。"
        case "持续功耗", "60 秒持续":
            return "最近 60 秒总功耗的滚动平均，更接近长时间烤机能稳定维持的功耗水平。"
        case "5 分钟持续":
            return "最近 5 分钟总功耗的滚动平均。短测试可能没有足够窗口，因此会显示不可用；长时间烤机时它比瞬时峰值更能说明持续释放能力。"
        case "估算能耗":
            return "把采样到的功耗按时间积分得到的估算电量消耗，单位 Wh。它适合看一段测试大概消耗了多少电。"
        case "模式":
            return "这次 Session 使用的压力测试模式：CPU、GPU 或 CPU + GPU。不同模式的功耗和温度表现会明显不同。"
        case "持续时间":
            return "这次压力测试从开始到停止的实际运行时间。下方会显示停止原因，例如用户手动停止或热状态自动停止。"
        case "CPU 温度":
            return "当前显示的是匹配到的 CPU 相关温度传感器最高值，不是所有核心平均值。用最高值更适合判断烤机安全边界。"
        case "CPU 峰值温度":
            return "本次 Session 里记录到的最高 CPU 温度，取 CPU 相关传感器的最高点。它比平均温度更适合作为安全参考。"
        case "GPU 温度":
            return "当前显示的是匹配到的 GPU 相关温度传感器最高值，不是平均值。Metal 压力测试时它通常比硬盘或环境温度变化更快。"
        case "GPU 峰值温度":
            return "本次 Session 里记录到的最高 GPU 温度。运行 Metal 或联合烤机时，这个值能反映图形核心区域的热压力。"
        case "芯片温度":
            return "SoC/PMU 芯片热趋势，来自 AppleSMC/HID 中的 SoC、PMU TDie/TDev、PMGR SoC Die、TPD/TRD/TCDX/TCMb/TCMz 等系统暴露的芯片传感器。"
        case "芯片峰值温度":
            return "本次 Session 中 SoC/PMU 等芯片区域记录到的最高温度。Apple Silicon 把 CPU、GPU 和控制器集成在一起，所以它适合看整颗芯片热压力。"
        case "最高温度":
            return "CPU、GPU、SoC 可读温度中的最高点，用来快速判断这次测试最热的芯片区域。"
        case "平均温度":
            return "测试期间每个采样点的 CPU/GPU/SoC 最高温度再取平均，用来看整体热平台，不替代峰值安全判断。"
        case "风扇转速":
            return "当前可读风扇中的最高转速。双风扇机型在数据概览里会拆成左风扇和右风扇分别显示。"
        case "峰值风扇转速":
            return "本次 Session 中记录到的最高风扇转速。低负载时风扇可能为 0 RPM，这是 macOS 正常散热策略。"
        case "左风扇":
            return "AppleSMC 的第 1 个风扇转速，通常对应左侧风扇。不同机型的物理命名可能略有差异。"
        case "右风扇":
            return "AppleSMC 的第 2 个风扇转速，通常对应右侧风扇。单风扇或无风扇机型会显示不可用。"
        case "硬盘温度":
            return "系统内置主硬盘的 SMART/NVMe 当前温度，优先通过 smartctl 读取，失败时使用 diskutil 的 SMART 温度字段。这个值应接近硬盘健康工具里的主硬盘温度。"
        case "存储芯片热点":
            return "AppleSMC 暴露的 NAND/存储区域热点，取 TN/TH/Ts/TS 等存储相关传感器中的最高值。它可能代表 NAND 或控制器附近温度，不等同于硬盘 SMART 当前温度。"
        case "SSD / NAND":
            return "旧名称下显示的是 AppleSMC 的 NAND/存储区域热点，不是硬盘 SMART 温度。新版会优先改用硬盘温度或明确标注为存储芯片热点。"
        case "Wi-Fi 模块":
            return "无线模块或 Airport 相关温度传感器。不同 Mac 暴露程度不同，读不到时会显示不可用。"
        case "气流温度":
            return "机身内部气流/进出风附近温度，适合判断整机散热环境。它通常低于芯片热点温度。"
        case "掌托/环境":
            return "掌托、机身环境或电池附近的低温区传感器，适合判断体感温度趋势，不代表芯片核心温度。"
        case "P 核频率":
            return "性能核心集群频率，来自 powermetrics。长时间满载后如果温度或功耗受限，这里可能下降。"
        case "E 核频率":
            return "效率核心集群频率，来自 powermetrics。它反映后台和低功耗核心在压力期间的运行状态。"
        case "GPU 频率":
            return "GPU 频率，来自 powermetrics。Metal 压力测试时可用来判断 GPU 是否持续运行在较高频率。"
        case "热状态":
            return "macOS 的系统热状态：Nominal、Fair、Serious、Critical。它是系统综合判断，不等于某一个传感器温度。"
        case "最差热状态":
            return "本次 Session 里出现过的最严重 macOS 热状态。Nominal 最轻，Critical 最严重；它是系统综合判断，不等于某一个温度。"
        case "采样完整度":
            return "非降级样本占总样本的比例。完整度越高，功耗、频率和稳定性判断越可信；降级通常来自 Helper 或 powermetrics 不可用。"
        case "有效采样率":
            return "与当前测试模式相关的功耗和频率字段同时有效的样本比例。它比只统计非降级来源更严格。"
        case "采样间隔":
            return "这次 Session 平均多久保存一条样本。数值越小，曲线越密；但系统采样、Helper 响应和机器负载都会让实际间隔略有波动。"
        case "完整 CSV":
            return "表示本次 Session 是否已经保存完整采样 CSV。历史 JSON 只保留轻量曲线，完整 CSV 保存全量原始样本，适合复盘长时间测试。"
        case "降频迹象":
            return "根据前后段功耗、P 核/GPU 频率、温度、热状态和降级样本比例做趋势判断。它不是绝对实验室结论。"
        case "频率限制证据":
            return "只有相关核心频率明显回落，并同时出现温度或系统热状态压力时才显示为是；轻微功耗波动不会直接算作降频。"
        case "报告样本":
            return "左侧是历史 JSON 保存的轻量曲线样本，右侧是本次完整采样数量。完整 CSV 会保存全量数据，便于复核。"
        case "持续性能释放稳定程度":
            return "比较测试前段与后段的功耗、频率、温度、热状态和降级样本，判断持续释放是否稳定。它是趋势提示，不是认证结论。"
        case "运行时间":
            return "当前压力测试 Session 已运行时间。未开始烤机时显示 00:00。"
        default:
            return nil
        }
    }
}

struct KeyValueRow: View {
    var title: String
    var value: String
    var monospaced = false
    var helpTitle: String?
    var help: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(L10n.t(title))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let helpTitle, let help {
                    InfoHelpButton(title: helpTitle, message: help)
                }
            }
            Spacer(minLength: 18)
            Text(L10n.t(value))
                .font(monospaced ? .body.monospaced() : .body)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.callout)
        .padding(.vertical, 5)
    }
}

extension StressPhase {
    var tint: Color {
        switch self {
        case .idle: .gray
        case .starting: .blue
        case .running: .green
        case .stopping: .orange
        case .stopped: .blue
        case .failed: .red
        }
    }

    var symbolName: String {
        switch self {
        case .idle: "pause.circle"
        case .starting: "play.circle"
        case .running: "flame.fill"
        case .stopping: "stop.circle"
        case .stopped: "checkmark.circle"
        case .failed: "exclamationmark.triangle.fill"
        }
    }
}

extension String {
    var thermalTint: Color {
        switch self {
        case "Nominal": .green
        case "Fair": .blue
        case "Serious": .orange
        case "Critical": .red
        default: .gray
        }
    }
}
