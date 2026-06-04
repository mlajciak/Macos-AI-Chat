import Foundation
import SwiftUI

extension ChatViewModel {
    func toggleSettings() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isSettingsOpen.toggle()
        }
    }

    func closeOverlays() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isSettingsOpen = false
        }
    }
}
