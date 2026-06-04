import Foundation
import SwiftUI

extension ChatViewModel {
    func toggleSessionBrowser() {
        withAnimation(.easeInOut(duration: 0.22)) {
            if isSessionBrowserOpen {
                isSessionBrowserOpen = false
            } else {
                isSettingsOpen = false
                isSessionBrowserOpen = true
            }
        }
    }

    func toggleSettings() {
        withAnimation(.easeInOut(duration: 0.22)) {
            if isSettingsOpen {
                isSettingsOpen = false
            } else {
                isSessionBrowserOpen = false
                isSettingsOpen = true
            }
        }
    }

    func closeOverlays() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isSessionBrowserOpen = false
            isSettingsOpen = false
        }
    }

    func toggleExpandedSidebar() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isExpandedSidebarVisible.toggle()
        }
        onExpandedSidebarVisibilityChanged?()
    }
}
