import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let windowController = ChatWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppTypography.registerFonts()
        windowController.show()
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

    @objc func toggleWindowMode() {
        windowController.toggleMode()
    }
}
