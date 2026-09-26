// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI
import XCTest
@testable import ShixinStressPower

final class SidebarGeometryTests: XCTestCase {
    @MainActor
    func testMacOS27SidebarMatchesReferenceRowPitch() throws {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27 else {
            throw XCTSkip("This compatibility profile applies only to macOS 27")
        }
        // Lay out the real view in an unshown test window; do not interact with the desktop.
        let host = NSHostingView(rootView: SidebarView(selection: .constant(.monitor)))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 250, height: 1000),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.close() }
        for _ in 0..<10 {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        let table = try XCTUnwrap(findTable(in: host))
        XCTAssertEqual(table.numberOfRows, AppSection.allCases.count)
        for row in 1..<table.numberOfRows {
            let pitch = table.rect(ofRow: row).minY - table.rect(ofRow: row - 1).minY
            XCTAssertEqual(pitch, 32, accuracy: 0.5, "Row \(row) pitch")
        }
    }

    @MainActor
    private func findTable(in view: NSView) -> NSTableView? {
        if let table = view as? NSTableView { return table }
        for child in view.subviews {
            if let table = findTable(in: child) { return table }
        }
        return nil
    }
}
