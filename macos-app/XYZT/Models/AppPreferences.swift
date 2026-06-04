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

    var fontSettings: AppFontSettings {
        AppFontSettings(
            bodyPointSize: CGFloat(bodyPointSize),
            familyMode: fontFamilyMode,
            customFamilyName: customFontFamily
        )
    }

    init() {
        let defaults = UserDefaults.standard
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

    static func parsePointSize(_ text: String) -> CGFloat {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else {
            return AppFontSettings.defaultBodyPointSize
        }
        return CGFloat(clampPointSize(value))
    }
}
