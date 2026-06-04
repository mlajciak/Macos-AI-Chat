import SwiftUI

// MARK: - Header path menu

struct SessionPathMenu: View {
    @Bindable var viewModel: ChatViewModel

    private var fontSettings: AppFontSettings { viewModel.preferences.fontSettings }
    @State private var isHovered = false

    var body: some View {
        Group {
            if viewModel.hasWorkspace {
                Menu {
                    sessionMenuItems
                } label: {
                    sessionPathLabel
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
            } else {
                Button(action: { viewModel.openProjectFolder() }) {
                    sessionPathLabel
                }
                .buttonStyle(.plain)
            }
        }
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .macTooltip(viewModel.hasWorkspace ? "Switch project or session" : "Open a project folder")
    }

    @ViewBuilder
    private var sessionMenuItems: some View {
        Button("Open Folder…", systemImage: "folder.badge.plus") {
            viewModel.openProjectFolder()
        }

        if !viewModel.recentProjects.isEmpty {
            Divider()

            ForEach(viewModel.recentProjects) { project in
                Menu {
                    ForEach(viewModel.threads(for: project.id)) { thread in
                        Button {
                            viewModel.selectThread(thread.id)
                        } label: {
                            if thread.id == viewModel.activeThreadId {
                                Label(thread.title, systemImage: "checkmark")
                            } else {
                                Text(thread.title)
                            }
                        }
                    }
                } label: {
                    Label(project.name, systemImage: "folder.fill")
                }
            }
        }
    }

    private var sessionPathLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: "folder")
                .font(fontSettings.font(size: fontSettings.iconPointSize, weight: .medium))
                .foregroundStyle(.secondary)
            if viewModel.hasWorkspace {
                Text(viewModel.activeProject.name)
                    .font(fontSettings.font(for: .caption, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("/")
                    .font(fontSettings.font(for: .caption))
                    .foregroundStyle(.tertiary)
                Text(viewModel.activeChatTitle)
                    .font(fontSettings.font(for: .caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Open folder…")
                    .font(fontSettings.font(for: .caption, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.down")
                .font(fontSettings.font(size: fontSettings.smallIconPointSize, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            GlassChromeBackground(
                material: .hudWindow,
                shape: .capsule,
                isHovered: isHovered
            )
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
                    action: viewModel.openProjectFolder
                )

                ForEach(viewModel.recentProjects) { project in
                    ProjectFolderSection(
                        project: project,
                        threads: viewModel.threads(for: project.id),
                        activeThreadId: viewModel.activeThreadId,
                        fontSettings: fontSettings,
                        onSelect: { viewModel.selectThread($0) },
                        onDelete: { viewModel.deleteThread($0) }
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

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "folder.badge.plus")
                    .font(fontSettings.font(size: fontSettings.iconPointSize, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                Text("Open folder…")
                    .font(fontSettings.font(for: .caption))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 10)
            .pillRow()
            .pillBackground(
                fill: isHovered ? Color.primary.opacity(0.07) : Color.clear
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(fontSettings.font(size: fontSettings.iconPointSize, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(project.name)
                    .font(fontSettings.font(for: .caption, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(.leading, 2)

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
    private static let trailingOverlayWidth: CGFloat = 88
    private static let titleTrailingFadeWidth: CGFloat = 18

    let thread: ChatThread
    let isActive: Bool
    let fontSettings: AppFontSettings
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            SessionStatusIndicator(isRunning: thread.isRunning)

            ZStack(alignment: .trailing) {
                Text(thread.title)
                    .font(fontSettings.font(for: .caption, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mask(titleFadeMask)

                trailingActionsOverlay
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .pillRow(height: Self.rowHeight)
        .pillBackground(fill: rowBackground)
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
    }

    private var titleFadeMask: some View {
        let fadeWidth = isHovered
            ? Self.trailingOverlayWidth + Self.titleTrailingFadeWidth
            : Self.titleTrailingFadeWidth

        return HStack(spacing: 0) {
            Rectangle().fill(Color.black)
            LinearGradient(
                colors: [.black, .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: fadeWidth)
        }
        .frame(maxWidth: .infinity)
    }

    private var trailingActionsOverlay: some View {
        HStack(spacing: 6) {
            Text(SessionRelativeTime.label(since: thread.lastActiveAt))
                .font(fontSettings.font(for: .caption))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(fontSettings.font(size: fontSettings.smallIconPointSize, weight: .medium))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red.opacity(0.85))
            .macTooltip("Delete session")
        }
        .padding(.leading, 10)
        .padding(.trailing, 2)
        .frame(width: Self.trailingOverlayWidth, alignment: .trailing)
        .background(alignment: .trailing) {
            LinearGradient(
                colors: [.clear, overlayScrimTrailing],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: Self.trailingOverlayWidth + 16)
        }
        .opacity(isHovered ? 1 : 0)
        .allowsHitTesting(isHovered)
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }

    /// Matches the row pill fill so the title fades under the trailing overlay.
    private var overlayScrimTrailing: Color {
        if isActive {
            return Color.primary.opacity(0.1)
        }
        return Color.primary.opacity(0.07)
    }

    private var rowBackground: Color {
        if isActive {
            return Color.primary.opacity(0.1)
        }
        if isHovered {
            return Color.primary.opacity(0.07)
        }
        return Color.clear
    }
}

// MARK: - Session status (9×9)

struct SessionStatusIndicator: View {
    static let size: CGFloat = 9

    let isRunning: Bool

    var body: some View {
        Group {
            if isRunning {
                RunningDotsIndicator(compact: true)
            } else {
                Circle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 3, height: 3)
            }
        }
        .frame(width: Self.size, height: Self.size)
    }
}

// MARK: - Running indicator (3×2)

struct RunningDotsIndicator: View {
    var compact: Bool = false

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
                        .fill(Color.primary.opacity(dotOpacity(index: index, tick: tick)))
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
