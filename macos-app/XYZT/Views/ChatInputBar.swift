import AppKit
import SwiftUI

struct ChatInputBar: View {
    @Binding var draft: String
    @Binding var selectedModelId: String
    let onSend: () -> Void
    var expandedMode: Bool = false
    var usesHudMaterial: Bool = false
    @FocusState private var isFocused: Bool

    private var glassMaterial: NSVisualEffectView.Material {
        usesHudMaterial ? .hudWindow : .popover
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
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            isFocused = true
        }
    }

    private var messageRow: some View {
        TextField("Message \(AppBranding.name)…", text: $draft, axis: .vertical)
            .textFieldStyle(.plain)
            .font(AppTypography.mono(size: AppTypography.bodySize))
            .lineLimit(2 ... 4)
            .focused($isFocused)
            .onSubmit { submit() }
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var controlRow: some View {
        HStack(alignment: .center, spacing: 8) {
            ModelSelectorView(selectedModelId: $selectedModelId, isDisabled: false)
            Spacer(minLength: 4)
            sendButton
        }
    }

    private var sendButton: some View {
        Button(action: submit) {
            HStack(spacing: 4) {
                Text("Send")
                    .font(AppTypography.mono(size: AppTypography.captionSize, weight: .medium))
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(canSend ? Color.white : Color.secondary.opacity(0.5))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(canSend ? Color.accentColor : Color.primary.opacity(0.1))
            }
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .keyboardShortcut(.return, modifiers: expandedMode ? .command : [])
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard canSend else { return }
        onSend()
        isFocused = true
    }
}
