import AppKit
import SwiftUI

/// Hue picks the target color; spread (intensity) blends it into accent, fills, strokes, and glass.
enum AppAccentPalette {
    static let defaultHue: Double = systemHue()

    static func systemHue() -> Double {
        hue(from: NSColor.controlAccentColor)
    }

    /// Full-strength swatch for the hue slider (ignores spread).
    static func previewColor(hue: Double) -> Color {
        Color(nsColor: accentNSColor(hue: hue))
    }

    static func themeColors(hue: Double, spread: Double) -> AppThemeColors {
        let clampedSpread = min(max(spread, 0), 1)
        return AppThemeColors(
            accent: themedAccent(hue: hue, spread: clampedSpread),
            hue: hue,
            spread: clampedSpread
        )
    }

    static func themedAccent(hue: Double, spread: Double) -> Color {
        themedBlend(
            base: NSColor.controlAccentColor,
            tint: accentNSColor(hue: hue),
            spread: spread
        )
    }

    static func themedNeutral(opacity: Double, hue: Double, spread: Double) -> Color {
        let base = NSColor.labelColor.withAlphaComponent(CGFloat(opacity))
        let tint = accentNSColor(hue: hue).withAlphaComponent(CGFloat(opacity))
        return themedBlend(base: base, tint: tint, spread: spread, fallback: Color.primary.opacity(opacity))
    }

    static func themedLabel(opacity: Double = 1, hue: Double, spread: Double) -> Color {
        let base = NSColor.labelColor.withAlphaComponent(CGFloat(opacity))
        let tint = accentNSColor(hue: hue).withAlphaComponent(CGFloat(opacity))
        return themedBlend(base: base, tint: tint, spread: spread, fallback: Color.primary.opacity(opacity))
    }

    static func themedSecondary(opacity: Double = 1, hue: Double, spread: Double) -> Color {
        let base = NSColor.secondaryLabelColor.withAlphaComponent(CGFloat(opacity))
        let tint = accentNSColor(hue: hue).withAlphaComponent(CGFloat(opacity * 0.85))
        return themedBlend(
            base: base,
            tint: tint,
            spread: spread,
            fallback: Color.secondary.opacity(opacity)
        )
    }

    static func themedWhite(overlayOpacity: Double, hue: Double, spread: Double) -> Color {
        let base = NSColor.white.withAlphaComponent(CGFloat(overlayOpacity))
        let tint = accentNSColor(hue: hue).withAlphaComponent(CGFloat(overlayOpacity))
        return themedBlend(base: base, tint: tint, spread: spread, fallback: Color.white.opacity(overlayOpacity))
    }

    static func accentNSColor(hue: Double) -> NSColor {
        let system = NSColor.controlAccentColor.usingColorSpace(.deviceRGB)
            ?? NSColor.controlAccentColor

        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        var ignoredHue: CGFloat = 0
        system.getHue(
            &ignoredHue,
            saturation: &saturation,
            brightness: &brightness,
            alpha: &alpha
        )

        return NSColor(
            hue: CGFloat(min(max(hue, 0), 1)),
            saturation: saturation,
            brightness: brightness,
            alpha: alpha
        )
    }

    private static func themedBlend(
        base: NSColor,
        tint: NSColor,
        spread: Double,
        fallback: Color? = nil
    ) -> Color {
        let clampedSpread = min(max(spread, 0), 1)
        guard clampedSpread > 0.0001 else {
            if let fallback { return fallback }
            return Color(nsColor: base)
        }

        if let blended = base.blended(withFraction: CGFloat(clampedSpread), of: tint) {
            return Color(nsColor: blended)
        }
        return Color(nsColor: tint)
    }

    private static func hue(from color: NSColor) -> Double {
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Double(h)
    }
}

struct AppThemeColors: Equatable {
    var accent: Color
    var hue: Double
    var spread: Double

    static let `default` = AppThemeColors(
        accent: Color(nsColor: .controlAccentColor),
        hue: AppAccentPalette.defaultHue,
        spread: 0
    )

    var fieldFill: Color { AppAccentPalette.themedNeutral(opacity: 0.06, hue: hue, spread: spread) }
    var fieldStroke: Color { AppAccentPalette.themedNeutral(opacity: 0.1, hue: hue, spread: spread) }
    var hoverFill: Color { AppAccentPalette.themedNeutral(opacity: 0.07, hue: hue, spread: spread) }
    var subtleFill: Color { AppAccentPalette.themedNeutral(opacity: 0.05, hue: hue, spread: spread) }
    var mutedRowFill: Color { AppAccentPalette.themedNeutral(opacity: 0.06, hue: hue, spread: spread) }
    var overlayStroke: Color { AppAccentPalette.themedNeutral(opacity: 0.12, hue: hue, spread: spread) }
    var menuStroke: Color { AppAccentPalette.themedNeutral(opacity: 0.1, hue: hue, spread: spread) }
    var primaryText: Color { AppAccentPalette.themedLabel(hue: hue, spread: spread) }
    var secondary: Color { AppAccentPalette.themedSecondary(hue: hue, spread: spread) }
    var secondaryMuted: Color { AppAccentPalette.themedSecondary(opacity: 0.65, hue: hue, spread: spread) }
    var codeBlockFill: Color {
        AppAccentPalette.themedNeutral(opacity: 0.07, hue: hue, spread: spread)
    }
    var codeBlockFillSecondary: Color {
        AppAccentPalette.themedNeutral(opacity: 0.05, hue: hue, spread: spread)
    }
    var glassTintOpacity: Double { spread * 0.12 }
    var accentMuted: Color { accent.opacity(0.1) }
    var accentSelectionFill: Color { accent.opacity(0.2) }
    var accentSelectionStroke: Color { accent.opacity(0.55) }

    func neutral(_ opacity: Double) -> Color {
        AppAccentPalette.themedNeutral(opacity: opacity, hue: hue, spread: spread)
    }
}

private struct AppAccentColorKey: EnvironmentKey {
    static let defaultValue = Color.accentColor
}

private struct AppThemeColorsKey: EnvironmentKey {
    static let defaultValue = AppThemeColors.default
}

extension EnvironmentValues {
    var appAccentColor: Color {
        get { self[AppAccentColorKey.self] }
        set { self[AppAccentColorKey.self] = newValue }
    }

    var appThemeColors: AppThemeColors {
        get { self[AppThemeColorsKey.self] }
        set { self[AppThemeColorsKey.self] = newValue }
    }
}

extension View {
    func appAccentEnvironment(_ preferences: AppPreferences) -> some View {
        let theme = AppAccentPalette.themeColors(
            hue: preferences.primaryColorHue,
            spread: preferences.primaryColorIntensity
        )
        return appFontEnvironment(preferences)
            .environment(\.appAccentColor, theme.accent)
            .environment(\.appThemeColors, theme)
            .tint(theme.accent)
    }
}

/// Circular preview of the selected hue (settings hue slider).
struct HueColorSwatch: View {
    let hue: Double
    var size: CGFloat = 22

    var body: some View {
        Circle()
            .fill(AppAccentPalette.previewColor(hue: hue))
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.5)
            }
    }
}
