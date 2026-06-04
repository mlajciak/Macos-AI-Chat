import SwiftUI

struct ProjectSelectorView: View {
    @Binding var selectedProjectId: String
    var prominent: Bool = false

    private var selected: Project {
        ProjectCatalog.project(id: selectedProjectId)
    }

    var body: some View {
        Menu {
            ForEach(ProjectCatalog.demo) { project in
                Button {
                    selectedProjectId = project.id
                } label: {
                    HStack {
                        Text(project.name)
                            .font(AppTypography.mono(size: AppTypography.captionSize))
                        Spacer()
                        if project.id == selectedProjectId {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: prominent ? 6 : 4) {
                Image(systemName: "folder")
                    .font(.system(size: prominent ? 12 : 10, weight: .medium))
                    .foregroundStyle(prominent ? .primary : .secondary)
                Text(selected.name)
                    .font(AppTypography.mono(
                        size: prominent ? AppTypography.headlineSize : AppTypography.captionSize,
                        weight: prominent ? .medium : .regular
                    ))
                    .foregroundStyle(prominent ? .primary : .secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: prominent ? 9 : 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .menuStyle(.borderlessButton)
        .help("Switch project")
    }
}
