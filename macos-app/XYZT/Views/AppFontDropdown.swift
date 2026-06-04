import AppKit
import SwiftUI

// MARK: - Dropdown (floating glass popover — not clipped by input chrome)

struct AppFontDropdown<Label: View, MenuContent: View>: View {
    let fontSettings: AppFontSettings
    var fullWidth: Bool = true
    var arrowEdge: Edge = .bottom
    var glassMaterial: NSVisualEffectView.Material = .popover
    var menuMinWidth: CGFloat = 200
    var tooltip: String?
    @ViewBuilder let label: () -> Label
    @ViewBuilder let menuContent: (_ close: @escaping () -> Void) -> MenuContent

    @State private var isOpen = false

    var body: some View {
        dropdownTrigger
            .popover(isPresented: $isOpen, attachmentAnchor: .rect(.bounds), arrowEdge: arrowEdge) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    menuContent { isOpen = false }
                }
                .appScrollStyle()
            }
            .scrollbarsWhenNeeded()
            .padding(6)
            .frame(minWidth: menuMinWidth, alignment: .leading)
            .background {
                GlassSurface.sessionMenu(material: glassMaterial)
            }
        }
    }

    @ViewBuilder
    private var dropdownTrigger: some View {
        let button = Button {
            isOpen.toggle()
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)

        if let tooltip, !tooltip.isEmpty {
            button.macTooltip(tooltip)
        } else {
            button
        }
    }
}

// MARK: - Trigger label

struct AppDropdownTriggerLabel: View {
    let icon: String?
    let title: String
    let fontSettings: AppFontSettings
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(fontSettings.font(size: fontSettings.iconPointSize, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, alignment: .center)
            }

            Text(title)
                .font(fontSettings.font(for: .caption))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            if showsChevron {
                Image(systemName: "chevron.up.chevron.down")
                    .font(fontSettings.font(size: fontSettings.smallIconPointSize, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, AppDropdownChrome.horizontalPadding)
        .pillRow()
        .pillBackground(
            fill: AppDropdownChrome.fieldFill,
            stroke: AppDropdownChrome.fieldStroke
        )
    }
}

// MARK: - Rows

struct AppDropdownRow: View {
    let icon: String?
    let title: String
    var subtitle: String?
    let fontSettings: AppFontSettings
    var isSelected: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(fontSettings.font(size: fontSettings.iconPointSize, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, alignment: .center)
                }

                if let subtitle {
                    VStack(alignment: .leading, spacing: 2) {
                        titleLabel
                        Text(subtitle)
                            .font(fontSettings.font(size: max(fontSettings.captionPointSize - 1, 9)))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    titleLabel
                }

                Spacer(minLength: 4)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(fontSettings.font(size: fontSettings.iconPointSize, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .pillRow()
            .pillBackground(
                fill: isHovered ? Color.primary.opacity(0.07) : Color.clear
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var titleLabel: some View {
        Text(title)
            .font(fontSettings.font(for: .caption))
            .foregroundStyle(.primary)
            .lineLimit(1)
    }
}

// MARK: - Chrome

enum AppDropdownChrome {
    static let horizontalPadding: CGFloat = 12

    static var fieldFill: Color { Color.primary.opacity(0.06) }

    static var fieldStroke: Color { Color.primary.opacity(0.1) }
}
