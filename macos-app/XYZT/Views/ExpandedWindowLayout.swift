import SwiftUI

struct ExpandedWindowLayout: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        Group {
            if viewModel.isExpandedSidebarVisible {
                HSplitView {
                    ExpandedSidebarColumn(viewModel: viewModel)
                        .frame(
                            minWidth: FloatingChromeMetrics.sidebarMinWidth,
                            idealWidth: FloatingChromeMetrics.sidebarIdealWidth,
                            maxWidth: FloatingChromeMetrics.sidebarMaxWidth
                        )
                    expandedDetailColumn
                }
            } else {
                expandedDetailColumn
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $viewModel.isSettingsOpen) {
            ExpandedSettingsSheet(preferences: viewModel.preferences)
        }
        .onAppear {
            viewModel.closeOverlays()
        }
        .onChange(of: viewModel.isExpandedSidebarVisible) { _, _ in
            viewModel.onExpandedSidebarVisibilityChanged?()
        }
    }

    @ViewBuilder
    private var expandedDetailColumn: some View {
        if viewModel.hasWorkspace {
            ConversationLayout(
                draft: $viewModel.draft,
                selectedModelId: $viewModel.selectedModelId,
                menuModels: viewModel.menuModels,
                messages: viewModel.session.messages,
                isStreaming: viewModel.session.isStreaming,
                expandedMode: true,
                onSend: { viewModel.send() },
                onStop: { viewModel.stopGeneration() },
                onToolExpandedChange: { messageId, toolId, expanded in
                    viewModel.setToolExpanded(
                        messageId: messageId,
                        toolId: toolId,
                        isExpanded: expanded
                    )
                },
                usesHudMaterial: false,
                usesExternalTitleBar: true
            ) {
                EmptyView()
            }
        } else {
            OpenFolderGateView(
                fontSettings: viewModel.preferences.fontSettings,
                onOpenFolder: { viewModel.openProjectFolder() }
            )
        }
    }
}
