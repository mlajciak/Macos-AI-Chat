import SwiftUI

struct ProjectSelectorView: View {
    @Binding var selectedProjectId: String
    let projects: [Project]
    let fontSettings: AppFontSettings
    var prominent: Bool = false
    @Environment(\.appThemeColors) private var theme

    private var selected: Project {
        ProjectCatalog.project(id: selectedProjectId)
    }

    private var controlHeight: CGFloat {
        prominent ? AppChrome.rowHeight : AppChrome.compactControlHeight
    }

    var body: some View {
        AppFontDropdown(
            fontSettings: fontSettings,
            fullWidth: false,
            tooltip: "Switch project"
        ) {
            HStack(spacing: prominent ? 6 : 4) {
                Image(systemName: "folder")
                    .font(fontSettings.font(
                        size: prominent ? fontSettings.iconPointSize + 1 : fontSettings.iconPointSize,
                        weight: .medium
                    ))
                    .foregroundStyle(prominent ? theme.primaryText : theme.secondary)
                Text(selected.name)
                    .font(fontSettings.font(
                        for: prominent ? .headline : .caption,
                        weight: prominent ? .medium : .regular
                    ))
                    .foregroundStyle(prominent ? theme.primaryText : theme.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(fontSettings.font(size: fontSettings.smallIconPointSize, weight: .semibold))
                    .foregroundStyle(theme.tertiary)
            }
            .padding(.horizontal, 12)
            .pillRow(height: controlHeight)
            .pillBackground(
                height: controlHeight,
                fill: theme.fieldFill,
                stroke: theme.fieldStroke
            )
        } menuContent: { close in
            ForEach(projects) { project in
                AppDropdownRow(
                    icon: "folder",
                    title: project.name,
                    fontSettings: fontSettings,
                    isSelected: project.id == selectedProjectId
                ) {
                    selectedProjectId = project.id
                    close()
                }
            }
        }
    }
}
