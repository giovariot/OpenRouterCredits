import OpenRouterCreditsCore
import OpenRouterCreditsUI
import SwiftUI
import WidgetKit

struct CreditsEntryView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetFamily) private var family

    let entry: CreditsEntry

    var body: some View {
        let theme = WidgetTheme.resolved(
            style: entry.style,
            colorScheme: colorScheme,
            renderingMode: renderingMode
        )
        CreditsWidgetView(model: model, theme: theme)
            .containerBackground(theme.background, for: .widget)
            .widgetURL(URL(string: WidgetConstants.openURL))
    }

    private var model: CreditsWidgetModel {
        CreditsWidgetModel(
            size: family == .systemMedium ? .medium : .small,
            style: entry.style,
            snapshot: entry.snapshot,
            history: entry.history,
            lastError: entry.lastError,
            isConfigured: entry.isConfigured,
            now: entry.date
        )
    }
}

struct OpenRouterCreditsWidget: Widget {
    static let kind = "OpenRouterCreditsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: CreditsWidgetIntent.self,
            provider: CreditsTimelineProvider()
        ) { entry in
            CreditsEntryView(entry: entry)
        }
        .configurationDisplayName("Crediti OpenRouter")
        .description("Credito residuo e spesa su OpenRouter, aggiornati ogni pochi minuti.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}