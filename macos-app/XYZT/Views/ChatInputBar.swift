import AppKit
import SwiftUI

struct ChatInputBar: View {
    @Binding var draft: String
    @Binding var selectedModelId: String
    @Binding var selectedImageModelId: String
    let menuModels: [ChatModel]
    let imageMenuModels: [ChatModel]
    let fontSettings: AppFontSettings
    let isStreaming: Bool
    let onSend: () -> Void
    let onStop: () -> Void
    var expandedMode: Bool = false
    var usesHudMaterial: Bool = false
    @Environment(\.appThemeColors) private var theme
    @FocusState private var isFocused: Bool
    @State private var inputHeight: CGFloat = 24

    private var glassMaterial: NSVisualEffectView.Material {
        usesHudMaterial ? .hudWindow : .popover
    }

    private var minInputHeight: CGFloat {
        ChatInputMetrics.minHeight(for: fontSettings)
    }

    private var maxInputHeight: CGFloat {
        ChatInputMetrics.maxHeight(for: fontSettings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            messageRow
            controlRow
        }
        .padding(10)
        .background {
            GlassSurface.input(material: glassMaterial)
        }
        .overlay {
            if isStreaming {
                StreamingInputBorder(cornerRadius: 14)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isStreaming)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            isFocused = true
        }
        .onAppear {
            syncInputHeightToFont()
        }
        .onChange(of: fontSettings) { _, _ in
            syncInputHeightToFont()
        }
        .onChange(of: draft) { _, newValue in
            if newValue.isEmpty {
                inputHeight = minInputHeight
            }
        }
    }

    private var messageRow: some View {
        ZStack(alignment: .topLeading) {
            ChatInputTextView(
                text: $draft,
                height: $inputHeight,
                fontSettings: fontSettings,
                expandedMode: expandedMode,
                onSubmit: submit
            )
            .frame(height: inputHeight)
            .frame(maxWidth: .infinity, alignment: .topLeading)

            if draft.isEmpty {
                Text("What do you want to make?")
                    .font(fontSettings.font(for: .body))
                    .foregroundStyle(theme.tertiary)
                    .padding(.top, 2)
                    .allowsHitTesting(false)
            }
        }
    }

    private var controlRow: some View {
        HStack(alignment: .center, spacing: 8) {
            ModelSelectorView(
                selectedModelId: $selectedModelId,
                models: menuModels,
                fontSettings: fontSettings,
                glassMaterial: glassMaterial,
                isDisabled: false,
                menuLabel: "Agent"
            )
            ImageModelMenuButton(
                selectedImageModelId: $selectedImageModelId,
                models: imageMenuModels,
                fontSettings: fontSettings,
                glassMaterial: glassMaterial
            )
            Spacer(minLength: 4)
            if isStreaming {
                stopButton
            } else {
                sendButton
            }
        }
    }

    private var sendButton: some View {
        circularActionButton(
            systemImage: "arrow.up",
            foreground: canSend ? Color.white : theme.secondaryMuted,
            fill: canSend ? theme.accent : theme.fieldStroke,
            accessibilityLabel: "Send",
            action: submit
        )
        .disabled(!canSend)
        .keyboardShortcut(.return, modifiers: expandedMode ? .command : [])
    }

    private var stopButton: some View {
        circularActionButton(
            systemImage: "stop.fill",
            foreground: Color.white,
            fill: Color.red.opacity(0.9),
            accessibilityLabel: "Stop",
            action: onStop
        )
        .help("Stop generating")
    }

    private func circularActionButton(
        systemImage: String,
        foreground: Color,
        fill: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(fontSettings.font(size: fontSettings.iconPointSize, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: AppChrome.compactControlHeight, height: AppChrome.compactControlHeight)
                .background {
                    Circle()
                        .fill(fill)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard canSend else { return }
        onSend()
        inputHeight = minInputHeight
        isFocused = true
    }

    private func syncInputHeightToFont() {
        let minH = minInputHeight
        inputHeight = draft.isEmpty ? minH : min(max(inputHeight, minH), maxInputHeight)
    }
}
