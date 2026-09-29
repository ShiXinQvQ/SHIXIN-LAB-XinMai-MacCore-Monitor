// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import ShixinStressPowerCore

extension TelemetrySample {
    var systemPowerDetail: String {
        guard let reading = systemPower, reading.watts != nil else { return "整机读数不可用" }
        return reading.source == "AppleSMC.PSTR"
            ? "系统负载 · 不含电池充电"
            : "系统负载 · 硬件低频更新"
    }
}
