// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import ShixinStressPowerCore
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case monitor = "实时监测"
    case stress = "压力测试"
    case overview = "数据概览"
    case curves = "实时曲线"
    case system = "本机配置"
    case network = "网速测试"
    case history = "历史记录"
    case settings = "设置与关于"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .monitor: "waveform.path.ecg"
        case .stress: "flame.fill"
        case .network: "speedometer"
        case .overview: "square.grid.2x2.fill"
        case .curves: "chart.xyaxis.line"
        case .system: "laptopcomputer.and.iphone"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape.fill"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: AppSection? = .monitor
    @StateObject private var networkSpeedController = NetworkSpeedTestController()

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            ZStack {
                LabBackground()
                switch selection ?? .monitor {
                case .monitor:
                    MonitoringView {
                        selection = .stress
                    }
                case .stress:
                    StressTestView()
                case .network:
                    NetworkSpeedTestView(controller: networkSpeedController)
                case .overview:
                    DataOverviewView()
                case .curves:
                    RealtimeCurvesView()
                case .system:
                    SystemInfoView()
                case .history:
                    HistoryView()
                case .settings:
                    SettingsView()
                }
            }
        }
        .sheet(isPresented: $appState.shouldShowHelperOnboarding) {
            HelperOnboardingSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: stressConfirmationBinding) {
            StressStartConfirmationSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: reportReadyBinding) {
            PerformanceReportReadySheet(
                session: appState.completedReportSession,
                onDismiss: {
                    appState.dismissCompletedReportPrompt()
                },
                onViewReport: {
                    if let session = appState.completedReportSession {
                        appState.selectedSessionID = session.id
                    }
                    selection = .history
                    appState.dismissCompletedReportPrompt()
                }
            )
            .environmentObject(appState)
        }
        .onAppear {
            updateRealtimePresentation(for: selection)
        }
        .onChange(of: selection) { _, newSelection in
            updateRealtimePresentation(for: newSelection)
        }
        .onDisappear {
            networkSpeedController.cancelTest()
        }
    }

    private var stressConfirmationBinding: Binding<Bool> {
        Binding {
            appState.pendingStressConfirmation
        } set: { isPresented in
            if !isPresented {
                appState.cancelStartStress()
            }
        }
    }

    private var reportReadyBinding: Binding<Bool> {
        Binding {
            appState.completedReportSessionID != nil
        } set: { isPresented in
            if !isPresented {
                appState.dismissCompletedReportPrompt()
            }
        }
    }

    private func updateRealtimePresentation(for section: AppSection?) {
        switch section ?? .monitor {
        case .monitor, .overview, .curves, .system:
            appState.setRealtimePresentationActive(true)
        case .stress, .network, .history, .settings:
            appState.setRealtimePresentationActive(false)
        }
    }
}

struct SidebarView: View {
    @Binding var selection: AppSection?

    var body: some View {
        Group {
            if LabAppearanceProfile.usesStableSurfaces {
                sectionList
                    // The supplied macOS 26 screenshot has a 32 pt row pitch (64 px at 2x).
                    .environment(\.defaultMinListRowHeight, 32)
                    .padding(.horizontal, 6)
            } else {
                sectionList
            }
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("SHIXIN LAB")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Button {
                        NSWorkspace.shared.open(URL(string: "https://shixinqvq.com/")!)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "globe")
                            Text(L10n.t("访问官网"))
                        }
                        .font(.caption2.weight(.medium))
                    }
                    .buttonStyle(.link)
                    .controlSize(.small)
                }
                Text("芯脉 · MacCore Monitor · Stress & Power")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var sectionList: some View {
        List(AppSection.allCases, selection: $selection) { section in
            Group {
                if LabAppearanceProfile.usesStableSurfaces {
                    HStack(spacing: 8) {
                        Image(systemName: section.symbolName)
                            .font(.system(size: 14, weight: .regular))
                            .symbolRenderingMode(.monochrome)
                            .frame(width: 20)
                        Text(L10n.t(section.rawValue))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.primary)
                } else {
                    Label(L10n.t(section.rawValue), systemImage: section.symbolName)
                }
            }
            .tag(section)
        }
    }

}
