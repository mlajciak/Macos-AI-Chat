import AppKit
import SwiftUI

@main
struct XYZTApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandGroup(replacing: .appTermination) {
                Button("Quit \(AppBranding.name)") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }

            CommandMenu("Window") {
                Button("Show \(AppBranding.name)") {
                    appDelegate.showChatWindow()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Divider()

                Button("Hide \(AppBranding.name)") {
                    appDelegate.windowController.hideWindow()
                }
                .keyboardShortcut("w", modifiers: .command)

                Divider()

                Button("Toggle Expanded Window") {
                    appDelegate.windowController.toggleMode()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }
}
