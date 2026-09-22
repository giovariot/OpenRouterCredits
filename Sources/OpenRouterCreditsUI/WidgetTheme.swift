import OpenRouterCreditsCore
import SwiftUI
import WidgetKit

/// Colori ufficiali del marchio OpenRouter, presi dai file brand
/// `openrouter-light.svg` (#7624F4) e `openrouter-dark.svg` (#C8FF00).
public enum Brand {
    public static let purple = Color(red: 0x76 / 255, green: 0x24 / 255, blue: 0xF4 / 255)
    public static let lime = Color(red: 0xC8 / 255, green: 0xFF / 255, blue: 0x00 / 255)
    public static let ink = Color(red: 0x03 / 255, green: 0x08 / 255, blue: 0x0A / 255)
    public static let paper = Color(red: 0xFC / 255, green: 0xFC / 255, blue: 0xFE / 255)
}

public enum ResolvedScheme: Sendable {
    case light
    case dark
}

/// Colori e stili calcolati per la modalità di rendering richiesta dal sistema.
///
/// In `fullColor` si usano i due schemi del marchio; nelle modalità `accented`
/// e `vibrant` si lasciano fare al sistema (stili semantici + `widgetAccentable`)
/// così il widget si comporta come quelli di macOS.
public struct WidgetTheme {
    public let isFullColor: Bool
    public let background: AnyShapeStyle
    public let accent: Color
    public let textPrimary: Color
    public let textSecondary: Color
    public let textTertiary: Color
    public let track: Color
    public let barTint: LinearGradient

    public static func resolved(
        style: WidgetStyleOption,
        colorScheme: ColorScheme,
        renderingMode: WidgetRenderingMode
    ) -> WidgetTheme {
        let scheme: ResolvedScheme = {
            switch style {
            case .whitePurple: return .light
            case .blackGreen: return .dark
            case .automatic: return colorScheme == .dark ? .dark : .light
            }
        }()

        if renderingMode == .fullColor {
            switch scheme {
            case .light:
                return WidgetTheme(
                    isFullColor: true,
                    background: AnyShapeStyle(
                        LinearGradient(
                            colors: [Brand.paper, Color(red: 0xF4 / 255, green: 0xEF / 255, blue: 0xFF / 255)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    ),
                    accent: Brand.purple,
                    textPrimary: Brand.ink,
                    textSecondary: Brand.ink.opacity(0.62),
                    textTertiary: Brand.ink.opacity(0.42),
                    track: Brand.purple.opacity(0.14),
                    barTint: LinearGradient(
                        colors: [Brand.purple, Brand.purple.opacity(0.75)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            case .dark:
                return WidgetTheme(
                    isFullColor: true,
                    background: AnyShapeStyle(
                        LinearGradient(
                            colors: [Brand.ink, Color(red: 0x0A / 255, green: 0x12 / 255, blue: 0x0C / 255)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    ),
                    accent: Brand.lime,
                    textPrimary: Brand.paper,
                    textSecondary: Brand.paper.opacity(0.64),
                    textTertiary: Brand.paper.opacity(0.44),
                    track: Brand.lime.opacity(0.16),
                    barTint: LinearGradient(
                        colors: [Brand.lime, Brand.lime.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
        }

        return WidgetTheme(
            isFullColor: false,
            background: AnyShapeStyle(Color.clear),
            accent: .primary,
            textPrimary: .primary,
            textSecondary: .primary.opacity(0.62),
            textTertiary: .primary.opacity(0.42),
            track: .primary.opacity(0.16),
            barTint: LinearGradient(colors: [.primary, .primary.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
        )
    }
}