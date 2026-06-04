import SwiftUI

// MARK: - Header breadcrumb

struct SessionBreadcrumbButton: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        Button(action: viewModel.toggleSessionBrowser) {
            HStack(spacing: 5) {
                Image(systemName: "folder")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(viewModel.activeProject.name)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("/")
                    .foregroundStyle(.tertiary)
                Text(viewModel.activeChatTitle)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(viewModel.isSessionBrowserOpen ? 180 : 0))
            }
        }
        .buttonStyle(.plain)
        .help("Browse projects and sessions")
    }
}

// MARK: - Session list overlay

struct SessionBrowserOverlay: View {
    @Bindable var viewModel: ChatViewModel
    let usesHudMaterial: Bool

    var body: some View {
        FloatingMenuOverlay(
            title: "Switch session",
            closeHelp: "Close session menu",
            usesHudMaterial: usesHudMaterial,
            onClose: { viewModel.closeOverlays() }
        ) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    OpenFolderMenuRow(action: viewModel.openProjectFolder)

                    ForEach(viewModel.recentProjects) { project in
                        ProjectFolderSection(
                            project: project,
                            threads: viewModel.threads(for: project.id),
                            activeThreadId: viewModel.activeThreadId,
                            onSelect: { viewModel.selectThread($0) },
                            onDelete: { viewModel.deleteThread($0) }
                        )
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
            }
        }
    }
}

// MARK: - Open folder

private struct OpenFolderMenuRow: View {
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                Text("Open folder…")
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.07) : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Open a project folder on disk")
        .onHover { isHovered = $0 }
    }
}

// MARK: - Folder tree

private struct ProjectFolderSection: View {
    let project: Project
    let threads: [ChatThread]
    let activeThreadId: String
    let onSelect: (String) -> Void
    let onDelete: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(project.name)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(threads) { thread in
                    SessionTreeRow(
                        thread: thread,
                        isActive: thread.id == activeThreadId,
                        onSelect: { onSelect(thread.id) },
                        onDelete: { onDelete(thread.id) }
                    )
                }
            }
            .padding(.leading, 18)
        }
    }
}

private struct SessionTreeRow: View {
    private static let rowHeight: CGFloat = 32
    private static let trailingSlotWidth: CGFloat = 128

    let thread: ChatThread
    let isActive: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            SessionStatusIndicator(isRunning: thread.isRunning)

            Text(thread.title)
                .foregroundStyle(isActive ? Color.accentColor : .primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            HStack(spacing: 8) {
                Text(SessionRelativeTime.label(since: thread.lastActiveAt))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.85))
                .help("Delete session")
            }
            .frame(width: Self.trailingSlotWidth, alignment: .trailing)
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)
        }
        .padding(.horizontal, 8)
        .frame(height: Self.rowHeight)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowBackground)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
    }

    private var rowBackground: Color {
        if isActive {
            return Color.accentColor.opacity(0.12)
        }
        if isHovered {
            return Color.primary.opacity(0.07)
        }
        return Color.clear
    }
}

// MARK: - Session status (9×9)

private struct SessionStatusIndicator: View {
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
                        .fill(Color.accentColor.opacity(dotOpacity(index: index, tick: tick)))
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
