import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let windowController = ChatWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        AppTypography.registerFonts()
        windowController.show()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            windowController.show()
        }
        return true
    }

    @objc func showChatWindow() {
        windowController.show()
    }

}
