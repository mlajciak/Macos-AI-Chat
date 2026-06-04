import AppKit
import SwiftUI

// MARK: - Header path menu

struct SessionPathMenu: View {
    @Bindable var viewModel: ChatViewModel
    @Environment(\.appThemeColors) private var theme

    @State private var isMenuOpen = false

    private var fontSettings: AppFontSettings { viewModel.preferences.fontSettings }

    private var pathTooltip: String {
        if viewModel.hasWorkspace {
            "\(viewModel.activeProject.name) / \(viewModel.activeChatTitle)"
        } else {
            "Open a project folder"
        }
    }

    var body: some View {
        Button {
            if viewModel.hasWorkspace {
                isMenuOpen.toggle()
            } else {
                viewModel.openProjectFolder()
            }
        } label: {
            sessionPathChipLabel
        }
        .buttonStyle(.plain)
        .help(pathTooltip)
        .accessibilityLabel(pathTooltip)
        .popover(isPresented: $isMenuOpen, arrowEdge: .bottom) {
            SessionPathMenuPopover(viewModel: viewModel) {
                isMenuOpen = false
            }
        }
    }

    private var sessionPathChipLabel: some View {
        HeaderToolbarGlassChip(shape: .capsule) {
            HStack(spacing: 5) {
                Image(systemName: "folder")
                    .font(fontSettings.font(size: fontSettings.iconPointSize, weight: .medium))
                    .foregroundStyle(theme.primaryText)
                Text(sessionPathText)
                    .font(fontSettings.font(for: .caption, weight: .medium))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
                Image(systemName: "chevron.down")
                    .font(fontSettings.font(size: fontSettings.smallIconPointSize, weight: .semibold))
                    .foregroundStyle(theme.secondaryMuted)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
        }
    }

    private var sessionPathText: String {
        if viewModel.hasWorkspace {
            "\(viewModel.activeProject.name) / \(viewModel.activeChatTitle)"
        } else {
            "Open folder…"
        }
    }
}

private struct SessionPathMenuPopover: View {
    @Bindable var viewModel: ChatViewModel
    let onDismiss: () -> Void

    private var fontSettings: AppFontSettings { viewModel.preferences.fontSettings }

    var body: some View {
        SessionProjectTree(viewModel: viewModel)
            .frame(width: 280, height: 320)
            .onChange(of: viewModel.activeThreadId) { _, _ in
                onDismiss()
            }
    }
}

// MARK: - Project / session tree

struct SessionProjectTree: View {
    @Bindable var viewModel: ChatViewModel

    private var fontSettings: AppFontSettings { viewModel.preferences.fontSettings }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                OpenFolderMenuRow(
                    fontSettings: fontSettings,
                    action: {
                        viewModel.openProjectFolder()
                    }
                )

                ForEach(viewModel.recentProjects) { project in
                    ProjectFolderSection(
                        project: project,
                        threads: viewModel.threads(for: project.id),
                        activeThreadId: viewModel.activeThreadId,
                        fontSettings: fontSettings,
                        onSelect: { viewModel.selectThread($0) },
                        onDelete: { viewModel.deleteThread($0) },
                        onNewChat: { viewModel.createNewChat(in: project.id) }
                    )
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .appScrollStyle()
        }
        .scrollbarsWhenNeeded()
    }
}

// MARK: - Open folder

struct OpenFolderMenuRow: View {
    let fontSettings: AppFontSettings
    let action: () -> Void
    @Environment(\.appThemeColors) private var theme

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "folder.badge.plus")
                    .font(fontSettings.font(size: fontSettings.iconPointSize, weight: .medium))
                    .foregroundStyle(theme.secondary)
                    .frame(width: 18)

                Text("Open folder…")
                    .font(fontSettings.font(for: .caption))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 10)
            .pillRow()
            .pillBackground(
                fill: isHovered ? theme.hoverFill : Color.clear
            )
        }
        .buttonStyle(.plain)
        .macTooltip("Open a project folder on disk")
        .onHover { isHovered = $0 }
    }
}

// MARK: - Folder tree

struct ProjectFolderSection: View {
    let project: Project
    let threads: [ChatThread]
    let activeThreadId: String
    let fontSettings: AppFontSettings
    let onSelect: (String) -> Void
    let onDelete: (String) -> Void
    let onNewChat: () -> Void
    @Environment(\.appThemeColors) private var theme

    @State private var isFolderHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(fontSettings.font(size: fontSettings.iconPointSize, weight: .medium))
                    .foregroundStyle(theme.secondary)

                Text(project.name)
                    .font(fontSettings.font(for: .caption, weight: .medium))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if isFolderHovered {
                    Button(action: onNewChat) {
                        HeaderToolbarGlassChip(shape: .capsule) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.pencil")
                                    .font(
                                        fontSettings.font(
                                            size: fontSettings.smallIconPointSize,
                                            weight: .medium
                                        )
                                    )
                                Text("New chat")
                                    .font(fontSettings.font(for: .caption, weight: .medium))
                            }
                            .foregroundStyle(theme.primaryText)
                            .padding(.horizontal, 8)
                            .frame(height: 26)
                        }
                    }
                    .buttonStyle(.plain)
                    .macTooltip("New chat session")
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .padding(.horizontal, 2)
            .frame(height: 28)
            .contentShape(Rectangle())
            .onHover { isFolderHovered = $0 }
            .animation(.easeOut(duration: 0.15), value: isFolderHovered)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(threads) { thread in
                    SessionTreeRow(
                        thread: thread,
                        isActive: thread.id == activeThreadId,
                        fontSettings: fontSettings,
                        onSelect: { onSelect(thread.id) },
                        onDelete: { onDelete(thread.id) }
                    )
                }
            }
            .padding(.leading, 18)
        }
    }
}

struct SessionTreeRow: View {
    private static let rowHeight: CGFloat = 32

    let thread: ChatThread
    let isActive: Bool
    let fontSettings: AppFontSettings
    let onSelect: () -> Void
    let onDelete: () -> Void
    @Environment(\.appThemeColors) private var theme

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            SessionStatusIndicator(isRunning: thread.isRunning)

            Text(thread.title)
                .font(fontSettings.font(for: .caption, weight: isActive ? .semibold : .regular))
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            if isHovered {
                Text(SessionRelativeTime.label(since: thread.lastActiveAt))
                    .font(fontSettings.font(for: .caption))
                    .foregroundStyle(theme.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(2)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(fontSettings.font(size: fontSettings.smallIconPointSize, weight: .medium))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.85))
                .macTooltip("Delete session")
                .layoutPriority(2)
            }
        }
        .padding(.horizontal, 10)
        .pillRow(height: Self.rowHeight)
        .pillBackground(fill: rowBackground)
        .contentShape(Capsule(style: .continuous))
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }

    private var rowBackground: Color {
        if isActive {
            return theme.accentSelectionFill
        }
        if isHovered {
            return theme.hoverFill
        }
        return Color.clear
    }
}

// MARK: - Session status (9×9)

struct SessionStatusIndicator: View {
    static let size: CGFloat = 9

    let isRunning: Bool
    @Environment(\.appThemeColors) private var theme

    var body: some View {
        Group {
            if isRunning {
                RunningDotsIndicator(compact: true)
            } else {
                Circle()
                    .fill(theme.secondaryMuted)
                    .frame(width: 3, height: 3)
            }
        }
        .frame(width: Self.size, height: Self.size)
    }
}

// MARK: - Running indicator (3×2)

struct RunningDotsIndicator: View {
    var compact: Bool = false
    @Environment(\.appThemeColors) private var theme

    private let columns = 3
    private let rows = 2

    private var dotSize: CGFloat { compact ? 2 : 3 }
    private var gridSpacing: CGFloat { compact ? 1.5 : 2 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12)) { timeline in
            let tick = Int(timeline.date.timeIntervalSinceReferenceDate / 0.12)
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(dotSize), spacing: gridSpacing), count: columns),
                spacing: gridSpacing
            ) {
                ForEach(0 ..< columns * rows, id: \.self) { index in
                    Circle()
                        .fill(theme.primaryText.opacity(dotOpacity(index: index, tick: tick)))
                        .frame(width: dotSize, height: dotSize)
                }
            }
        }
    }

    private func dotOpacity(index: Int, tick: Int) -> Double {
        let phase = (tick + index) % 6
        switch phase {
        case 0: return 1
        case 1: return 0.75
        case 2: return 0.45
        default: return 0.25
        }
    }
}
