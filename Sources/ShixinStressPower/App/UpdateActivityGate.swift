// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Combine

/// A small, main-thread interlock. Leases last through cancellation cleanup and file writes.
@MainActor
final class UpdateActivityGate: ObservableObject {
    static let shared = UpdateActivityGate()

    @Published private(set) var updateInProgress = false
    @Published private(set) var activityCount = 0
    private var activities: Set<UUID> = []

    var canBeginUpdate: Bool { !updateInProgress && activities.isEmpty }

    func beginActivity() -> UUID? {
        guard !updateInProgress else { return nil }
        let token = UUID()
        activities.insert(token)
        activityCount = activities.count
        return token
    }

    func endActivity(_ token: UUID) {
        guard activities.remove(token) != nil else { return }
        activityCount = activities.count
    }

    func beginUpdate() -> Bool {
        guard canBeginUpdate else { return false }
        updateInProgress = true
        return true
    }

    func endUpdate() { updateInProgress = false }

    @discardableResult
    func allowsUserActivity() -> Bool {
        guard updateInProgress else { return true }
        let alert = NSAlert()
        alert.messageText = L10n.t("更新进行中")
        alert.informativeText = L10n.t("请先完成或取消软件更新，再开始测试、导出或 Helper 操作。")
        alert.addButton(withTitle: L10n.t("好"))
        alert.runModal()
        return false
    }

    func beginUserActivity() -> UUID? {
        guard allowsUserActivity() else { return nil }
        return beginActivity()
    }
}
