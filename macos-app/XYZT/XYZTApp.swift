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
            CommandMenu("Window") {
                Button("Show \(AppBranding.name)") {
                    appDelegate.showChatWindow()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Toggle Compact / Expanded") {
                    appDelegate.toggleWindowMode()
                }
                .keyboardShortcut("m", modifiers: [.command, .option])
            }
        }
    }
}
