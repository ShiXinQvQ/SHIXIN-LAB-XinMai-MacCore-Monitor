import AppKit
import ShixinStressPowerCore
import SwiftUI

@main
struct ShixinStressPowerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .frame(minWidth: 980, minHeight: 680)
                .task {
                    appDelegate.attach(appState)
                    appState.start()
                }
                .onDisappear {
                    if appState.isRunning {
                        appState.stopStress(reason: .appExit)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1180, height: 1000)
        .commands {
            CommandGroup(after: .newItem) {
                Button("开始 / 停止烤机") {
                    if appState.isRunning {
                        appState.stopStress()
                    } else {
                        appState.requestStartStress()
                    }
                }
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private weak var appState: AppState?
    private var isCompletingTermination = false

    func attach(_ appState: AppState) {
        self.appState = appState
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        WindowSizeController.applyDefaultMainWindowSize()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isCompletingTermination else {
            return .terminateNow
        }
        guard let appState, appState.needsAppExitCleanup else {
            appState?.stopTelemetry()
            return .terminateNow
        }

        isCompletingTermination = true
        Task { @MainActor in
            await appState.prepareForAppTermination()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState?.stopTelemetry()
    }
}

enum WindowSizeController {
    private static let defaultContentSize = NSSize(width: 1180, height: 1000)

    @MainActor
    static func applyDefaultMainWindowSize() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let window = NSApplication.shared.windows.first(where: { $0.isVisible && !($0 is NSPanel) }) else {
                return
            }
            window.setContentSize(defaultContentSize)
            if let screen = window.screen ?? NSScreen.main {
                var frame = window.frame
                let visible = screen.visibleFrame
                frame.origin.x = visible.midX - frame.width / 2
                frame.origin.y = visible.midY - frame.height / 2
                window.setFrame(frame, display: true)
            }
        }
    }
}
