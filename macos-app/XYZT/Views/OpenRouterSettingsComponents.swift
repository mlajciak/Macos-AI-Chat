import SwiftUI

// MARK: - Layout

struct SettingsFieldRow<Content: View>: View {
    let label: String
    let fontSettings: AppFontSettings
    @ViewBuilder var content: () -> Content
    @Environment(\.appThemeColors) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(fontSettings.font(for: .caption, weight: .medium))
                .foregroundStyle(theme.secondary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Model picker (shared by Agent / Image settings)

enum OpenRouterModelPickerKind {
    case agent
    case image

    var sectionTitle: String {
        switch self {
        case .agent: "Agent models"
        case .image: "Image models"
        }
    }

    var searchPlaceholder: String {
        switch self {
        case .agent: "Search text models"
        case .image: "Search image models"
        }
    }

    var outputModalities: [String] {
        switch self {
        case .agent: ["text"]
        case .image: ["image"]
        }
    }
}

enum OpenRouterModelLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

struct OpenRouterModelPickerSection: View {
    let kind: OpenRouterModelPickerKind
    @Bindable var preferences: AppPreferences
    let fontSettings: AppFontSettings

    @State private var models: [OpenRouterClient.Model] = []
    @State private var searchQuery = ""
    @State private var loadState: OpenRouterModelLoadState = .idle
    @Environment(\.appThemeColors) private var theme

    var body: some View {
        SettingsFieldRow(label: kind.sectionTitle, fontSettings: fontSettings) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(fontSettings.font(for: .caption))
                        .foregroundStyle(theme.tertiary)

                    TextField(kind.searchPlaceholder, text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(fontSettings.font(for: .caption))
                        .onSubmit { Task { await loadModels() } }
                }
                .padding(.horizontal, AppDropdownChrome.horizontalPadding)
                .pillRow()
                .pillBackground(fill: theme.fieldFill, stroke: theme.fieldStroke)

                HStack {
                    Text(statusText)
                        .font(fontSettings.font(for: .caption))
                        .foregroundStyle(theme.secondary)
                    Spacer()
                    Button("Refresh") {
                        Task { await loadModels() }
                    }
                    .buttonStyle(.plain)
                    .font(fontSettings.font(for: .caption, weight: .medium))
                    .disabled(!preferences.hasOpenRouterApiKey || isModelLoading)
                }

                OpenRouterModelListPanel(
                    models: filteredModels,
                    loadState: loadState,
                    fontSettings: fontSettings,
                    isEnabled: { modelId in
                        switch kind {
                        case .agent: preferences.isMenuModelEnabled(modelId)
                        case .image: preferences.isImageMenuModelEnabled(modelId)
                        }
                    },
                    onToggle: { model, enabled in
                        switch kind {
                        case .agent: preferences.setMenuModelEnabled(model, enabled: enabled)
                        case .image: preferences.setImageMenuModelEnabled(model, enabled: enabled)
                        }
                    }
                )
            }
        }
        .task(id: taskKey) {
            guard preferences.hasOpenRouterApiKey else {
                models = []
                loadState = .idle
                return
            }
            await loadModels()
        }
    }

    private var enabledMenuCount: Int {
        switch kind {
        case .agent: preferences.menuModelIds.count
        case .image: preferences.imageMenuModelIds.count
        }
    }

    private var isModelLoading: Bool {
        if case .loading = loadState { return true }
        return false
    }

    private var taskKey: String {
        "\(kind.sectionTitle)|\(preferences.openRouterApiKey)"
    }

    private var filteredModels: [OpenRouterClient.Model] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return models }
        return models.filter { model in
            let haystack = "\(model.id) \(model.name) \(model.description ?? "")".lowercased()
            return haystack.contains(query)
        }
    }

    private var statusText: String {
        switch loadState {
        case .idle:
            preferences.hasOpenRouterApiKey ? "Refresh to load" : "Needs API key"
        case .loading:
            "Loading models…"
        case .loaded:
            "\(filteredModels.count) shown · \(enabledMenuCount) in menu"
        case let .failed(message):
            message
        }
    }

    private func loadModels() async {
        guard preferences.hasOpenRouterApiKey else {
            models = []
            loadState = .idle
            return
        }
        loadState = .loading
        do {
            models = try await OpenRouterClient.listModels(
                apiKey: preferences.openRouterApiKey,
                query: OpenRouterClient.ModelQuery(
                    search: nil,
                    outputModalities: kind.outputModalities
                )
            )
            loadState = .loaded
        } catch {
            models = []
            loadState = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Usage chart

enum OpenRouterUsageLoadState: Equatable {
    case idle
    case loading
    case loaded(OpenRouterClient.KeyUsage)
    case failed(String)
}

struct OpenRouterUsageChartSection: View {
    @Bindable var preferences: AppPreferences
    let fontSettings: AppFontSettings
    @Environment(\.appThemeColors) private var theme

    @State private var loadState: OpenRouterUsageLoadState = .idle

    var body: some View {
        SettingsFieldRow(label: "Usage", fontSettings: fontSettings) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if case let .loaded(usage) = loadState, let remaining = usage.limitRemaining {
                        Text("\(formatCredits(remaining)) left")
                            .font(fontSettings.font(for: .caption))
                            .foregroundStyle(theme.secondary)
                    }
                    Spacer()
                    Button("Refresh") {
                        Task { await loadUsage() }
                    }
                    .buttonStyle(.plain)
                    .font(fontSettings.font(for: .caption, weight: .medium))
                    .disabled(!preferences.hasOpenRouterApiKey || isUsageLoading)
                }

                chartBody
            }
        }
        .task(id: preferences.openRouterApiKey) {
            guard preferences.hasOpenRouterApiKey else {
                loadState = .idle
                return
            }
            await loadUsage()
        }
    }

    @ViewBuilder
    private var chartBody: some View {
        switch loadState {
        case .idle:
            usagePlaceholder("—")
        case .loading:
            usagePlaceholder("…")
        case let .loaded(usage):
            VStack(alignment: .leading, spacing: 8) {
                OpenRouterUsageBarChart(
                    rows: [
                        ("Today", usage.usageDaily),
                        ("Week", usage.usageWeekly),
                        ("Month", usage.usageMonthly),
                    ],
                    maxValue: max(usage.usageMonthly, usage.usageWeekly, usage.usageDaily, 0.01),
                    fontSettings: fontSettings
                )
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.fieldFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(theme.fieldStroke, lineWidth: 0.5)
            }
        case let .failed(message):
            usagePlaceholder(message)
        }
    }

    private var isUsageLoading: Bool {
        if case .loading = loadState { return true }
        return false
    }

    private func usagePlaceholder(_ text: String) -> some View {
        Text(text)
            .font(fontSettings.font(for: .caption))
            .foregroundStyle(theme.tertiary)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .center)
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.fieldFill)
            }
    }

    private func loadUsage() async {
        guard preferences.hasOpenRouterApiKey else {
            loadState = .idle
            return
        }
        loadState = .loading
        do {
            let usage = try await OpenRouterClient.fetchKeyUsage(apiKey: preferences.openRouterApiKey)
            loadState = .loaded(usage)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    private func formatCredits(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

private struct OpenRouterUsageBarChart: View {
    let rows: [(label: String, value: Double)]
    let maxValue: Double
    let fontSettings: AppFontSettings
    @Environment(\.appThemeColors) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    Text(row.label)
                        .font(fontSettings.font(for: .caption))
                        .foregroundStyle(theme.secondary)
                        .frame(width: 72, alignment: .leading)

                    GeometryReader { geo in
                        let width = max(4, geo.size.width * CGFloat(row.value / maxValue))
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(theme.accent.opacity(0.85))
                            .frame(width: width, height: 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 10)

                    Text(String(format: "%.2f", row.value))
                        .font(fontSettings.font(for: .caption))
                        .monospacedDigit()
                        .foregroundStyle(theme.primaryText)
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Model list UI (shared)

enum OpenRouterModelListChrome {
    static let maxHeight: CGFloat = 220
    static let placeholderHeight: CGFloat = 120
    static let cornerRadius: CGFloat = 10
}

struct OpenRouterModelListPanel: View {
    let models: [OpenRouterClient.Model]
    let loadState: OpenRouterModelLoadState
    let fontSettings: AppFontSettings
    let isEnabled: (String) -> Bool
    let onToggle: (OpenRouterClient.Model, Bool) -> Void
    @Environment(\.appThemeColors) private var theme

    var body: some View {
        Group {
            switch loadState {
            case .loaded where !models.isEmpty:
                scrollableModelList
            default:
                placeholderBox
            }
        }
    }

    private var scrollableModelList: some View {
        modelListChrome(fixedHeight: OpenRouterModelListChrome.maxHeight) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(models, id: \.id) { model in
                        OpenRouterModelRow(
                            model: model,
                            isEnabled: isEnabled(model.id),
                            fontSettings: fontSettings
                        ) { enabled in
                            onToggle(model, enabled)
                        }
                    }
                }
                .appScrollStyle()
            }
            .scrollbarsWhenNeeded()
        }
    }

    private var placeholderBox: some View {
        modelListChrome(fixedHeight: OpenRouterModelListChrome.placeholderHeight) {
            placeholderContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func modelListChrome<Content: View>(
        fixedHeight: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: OpenRouterModelListChrome.cornerRadius, style: .continuous)
                .fill(theme.fieldFill)
            RoundedRectangle(cornerRadius: OpenRouterModelListChrome.cornerRadius, style: .continuous)
                .strokeBorder(theme.fieldStroke, lineWidth: 0.5)
            content().padding(6)
        }
        .frame(height: fixedHeight)
    }

    @ViewBuilder
    private var placeholderContent: some View {
        switch loadState {
        case .loading:
            ProgressView().controlSize(.small)
        case .loaded:
            Text("No models match your search.")
                .font(fontSettings.font(for: .caption))
                .foregroundStyle(theme.tertiary)
        case .idle, .failed:
            Text(idleOrErrorMessage)
                .font(fontSettings.font(for: .caption))
                .foregroundStyle(theme.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        default:
            EmptyView()
        }
    }

    private var idleOrErrorMessage: String {
        if case let .failed(message) = loadState { return message }
        return "Refresh to load"
    }
}

struct OpenRouterModelRow: View {
    private static let rowHeight: CGFloat = 36

    let model: OpenRouterClient.Model
    let isEnabled: Bool
    let fontSettings: AppFontSettings
    let onToggle: (Bool) -> Void

    @Environment(\.appThemeColors) private var theme
    @State private var isHovered = false

    var body: some View {
        Button {
            onToggle(!isEnabled)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(fontSettings.font(size: fontSettings.iconPointSize, weight: .medium))
                    .foregroundStyle(isEnabled ? theme.accent : theme.secondaryMuted)
                    .frame(width: 16, alignment: .center)

                VStack(alignment: .leading, spacing: 1) {
                    Text(model.name)
                        .font(fontSettings.font(for: .caption, weight: .medium))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                    Text(model.id)
                        .font(fontSettings.font(size: max(fontSettings.captionPointSize - 1, 9)))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: Self.rowHeight, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(rowFill)
            }
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var rowFill: Color {
        if isEnabled { return theme.accentMuted }
        if isHovered { return theme.mutedRowFill }
        return .clear
    }
}
