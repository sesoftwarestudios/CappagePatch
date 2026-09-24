import AppKit
import Darwin
import SwiftUI
import TimeCapsuleSMBApp

@main
struct CappagePatchApp: App {
    @NSApplicationDelegateAdaptor(AppCloseGuardApplicationDelegate.self) private var appCloseGuardDelegate

    init() {
        if CommandLine.arguments.contains("--validate-resources") {
            if let error = AppLaunchResourceValidation.validate() {
                fputs("\(error)\n", stderr)
                exit(70)
            }
            print("ok")
            exit(0)
        }

        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        WindowGroup(AppBrand.displayName) {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1180, height: 780)
    }
}
