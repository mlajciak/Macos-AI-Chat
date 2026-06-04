import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum ChatTitleModelSource: String, CaseIterable, Identifiable, Codable {
    case selectedChatModel
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .selectedChatModel: "Use selected chat model"
        case .custom: "Custom model"
        }
    }
}

enum AppFontFamilyMode: String, CaseIterable, Identifiable {
    case system
    case mono
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .mono: "Mono"
        case .custom: "Custom"
        }
    }

    var icon: String {
        switch self {
        case .system: "textformat"
        case .mono: "chevron.left.forwardslash.chevron.right"
        case .custom: "character.cursor.ibeam"
        }
    }
}

struct AppFontSettings: Equatable {
    var bodyPointSize: CGFloat
    var familyMode: AppFontFamilyMode
    var customFamilyName: String

    static let defaultBodyPointSize: CGFloat = 13

    static let `default` = AppFontSettings(
        bodyPointSize: defaultBodyPointSize,
        familyMode: .mono,
        customFamilyName: ""
    )

    var captionPointSize: CGFloat { max(bodyPointSize - 2, 9) }

    var headlinePointSize: CGFloat { bodyPointSize + 1 }
}

@Observable
@MainActor
final class AppPreferences {
    private enum Keys {
        static let theme = "xyzt.theme"
        static let fontSize = "xyzt.fontSize"
        static let fontSizeText = "xyzt.fontSizeText"
        static let fontSizePoints = "xyzt.fontSizePoints"
        static let fontFamily = "xyzt.fontFamily"
        static let fontFamilyMode = "xyzt.fontFamilyMode"
        static let customFontFamily = "xyzt.customFontFamily"
        static let menuModelIds = "xyzt.menuModelIds"
        static let modelLabels = "xyzt.modelLabels"
        static let chatTitleModelSource = "xyzt.chatTitleModelSource"
        static let chatTitleCustomModelId = "xyzt.chatTitleCustomModelId"
        static let compactWindowAnchor = "xyzt.compactWindowAnchor"
        static let compactFloatingOriginX = "xyzt.compactFloatingOriginX"
        static let compactFloatingOriginY = "xyzt.compactFloatingOriginY"
    }

    var menuModelIds: [String] {
        didSet { UserDefaults.standard.set(menuModelIds, forKey: Keys.menuModelIds) }
    }

    private(set) var modelLabels: [String: String] {
        didSet { Self.saveModelLabels(modelLabels) }
    }

    var openRouterApiKey: String {
        didSet { OpenRouterCredentialStore.save(openRouterApiKey) }
    }

    var hasOpenRouterApiKey: Bool {
        !openRouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var menuModels: [ChatModel] {
        ChatModelCatalog.menuModels(menuModelIds: menuModelIds, labels: modelLabels)
    }

    func setMenuModelEnabled(_ model: OpenRouterClient.Model, enabled: Bool) {
        var labels = modelLabels
        labels[model.id] = model.name
        modelLabels = labels

        var ids = menuModelIds
        if enabled {
            if !ids.contains(model.id) { ids.append(model.id) }
        } else {
            ids.removeAll { $0 == model.id }
        }
        menuModelIds = ids
    }

    func isMenuModelEnabled(_ modelId: String) -> Bool {
        menuModelIds.contains(modelId)
    }

    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) }
    }

    var bodyPointSize: Double {
        didSet {
            let clamped = Self.clampPointSize(bodyPointSize)
            if clamped != bodyPointSize {
                bodyPointSize = clamped
                return
            }
            UserDefaults.standard.set(bodyPointSize, forKey: Keys.fontSizePoints)
        }
    }

    var fontFamilyMode: AppFontFamilyMode {
        didSet { UserDefaults.standard.set(fontFamilyMode.rawValue, forKey: Keys.fontFamilyMode) }
    }

    var customFontFamily: String {
        didSet { UserDefaults.standard.set(customFontFamily, forKey: Keys.customFontFamily) }
    }

    var chatTitleModelSource: ChatTitleModelSource {
        didSet { UserDefaults.standard.set(chatTitleModelSource.rawValue, forKey: Keys.chatTitleModelSource) }
    }

    var chatTitleCustomModelId: String {
        didSet { UserDefaults.standard.set(chatTitleCustomModelId, forKey: Keys.chatTitleCustomModelId) }
    }

    var compactWindowAnchor: CompactWindowAnchor {
        didSet { UserDefaults.standard.set(compactWindowAnchor.rawValue, forKey: Keys.compactWindowAnchor) }
    }

    /// Bottom-left origin of the compact panel when `compactWindowAnchor` is `.floating`.
    var compactFloatingWindowOrigin: CGPoint? {
        didSet {
            let defaults = UserDefaults.standard
            if let compactFloatingWindowOrigin {
                defaults.set(compactFloatingWindowOrigin.x, forKey: Keys.compactFloatingOriginX)
                defaults.set(compactFloatingWindowOrigin.y, forKey: Keys.compactFloatingOriginY)
            } else {
                defaults.removeObject(forKey: Keys.compactFloatingOriginX)
                defaults.removeObject(forKey: Keys.compactFloatingOriginY)
            }
        }
    }

    var fontSettings: AppFontSettings {
        AppFontSettings(
            bodyPointSize: CGFloat(bodyPointSize),
            familyMode: fontFamilyMode,
            customFamilyName: customFontFamily
        )
    }

    init() {
        let defaults = UserDefaults.standard
        menuModelIds = defaults.stringArray(forKey: Keys.menuModelIds) ?? []
        modelLabels = Self.loadModelLabels()
        openRouterApiKey = OpenRouterCredentialStore.read() ?? ""
        if let raw = defaults.string(forKey: Keys.theme),
           let stored = AppTheme(rawValue: raw) {
            theme = stored
        } else {
            theme = .system
        }

        if defaults.object(forKey: Keys.fontSizePoints) != nil {
            bodyPointSize = Self.clampPointSize(defaults.double(forKey: Keys.fontSizePoints))
        } else if let stored = defaults.string(forKey: Keys.fontSizeText) {
            bodyPointSize = Self.clampPointSize(Double(Self.parsePointSize(stored)))
        } else if let legacy = defaults.string(forKey: Keys.fontSize) {
            bodyPointSize = Self.clampPointSize(Double(Self.parsePointSize(Self.migrateLegacyFontSize(legacy))))
        } else {
            bodyPointSize = Double(AppFontSettings.defaultBodyPointSize)
        }

        if let modeRaw = defaults.string(forKey: Keys.fontFamilyMode),
           let mode = AppFontFamilyMode(rawValue: modeRaw) {
            fontFamilyMode = mode
            customFontFamily = defaults.string(forKey: Keys.customFontFamily) ?? ""
        } else if let legacyFamily = defaults.string(forKey: Keys.fontFamily) {
            let (mode, custom) = Self.migrateLegacyFontFamily(legacyFamily)
            fontFamilyMode = mode
            customFontFamily = custom
        } else {
            fontFamilyMode = .mono
            customFontFamily = ""
        }

        if let raw = defaults.string(forKey: Keys.chatTitleModelSource),
           let source = ChatTitleModelSource(rawValue: raw) {
            chatTitleModelSource = source
        } else {
            chatTitleModelSource = .selectedChatModel
        }
        chatTitleCustomModelId = defaults.string(forKey: Keys.chatTitleCustomModelId) ?? ""
        if let raw = defaults.string(forKey: Keys.compactWindowAnchor),
           let anchor = CompactWindowAnchor(rawValue: raw) {
            compactWindowAnchor = anchor
        } else {
            compactWindowAnchor = .default
        }
        if defaults.object(forKey: Keys.compactFloatingOriginX) != nil,
           defaults.object(forKey: Keys.compactFloatingOriginY) != nil {
            compactFloatingWindowOrigin = CGPoint(
                x: defaults.double(forKey: Keys.compactFloatingOriginX),
                y: defaults.double(forKey: Keys.compactFloatingOriginY)
            )
        } else {
            compactFloatingWindowOrigin = nil
        }

    }

    private static func clampPointSize(_ value: Double) -> Double {
        min(max(value, 8), 32)
    }

    private static func migrateLegacyFontSize(_ raw: String) -> String {
        switch raw {
        case "small": "11"
        case "large": "15"
        case "default": String(Int(AppFontSettings.defaultBodyPointSize))
        default: raw
        }
    }

    private static func migrateLegacyFontFamily(_ raw: String) -> (AppFontFamilyMode, String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.lowercased() == "system" {
            return (.system, "")
        }
        if AppTypography.isBundledMonoFamily(trimmed) {
            return (.mono, "")
        }
        return (.custom, trimmed)
    }

    private static func loadModelLabels() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: Keys.modelLabels),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return decoded
    }

    private static func saveModelLabels(_ labels: [String: String]) {
        guard let data = try? JSONEncoder().encode(labels) else { return }
        UserDefaults.standard.set(data, forKey: Keys.modelLabels)
    }

    static func parsePointSize(_ text: String) -> CGFloat {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else {
            return AppFontSettings.defaultBodyPointSize
        }
        return CGFloat(clampPointSize(value))
    }
}
