import AppIntents
import OpenRouterCreditsCore
import WidgetKit

/// Le due varianti colore del brand, selezionabili modificando il widget.
enum WidgetStyleEntity: String, AppEnum {
    case automatic
    case whitePurple
    case blackGreen

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Schema colori"

    static var caseDisplayRepresentations: [WidgetStyleEntity: DisplayRepresentation] = [
        .automatic: DisplayRepresentation(
            title: "Automatico",
            subtitle: "Segue l'aspetto chiaro o scuro di macOS"
        ),
        .whitePurple: DisplayRepresentation(
            title: "Giorno",
            subtitle: "Fondo bianco, accento viola"
        ),
        .blackGreen: DisplayRepresentation(
            title: "Notte",
            subtitle: "Fondo nero, accento verde"
        ),
    ]

    var option: WidgetStyleOption {
        WidgetStyleOption(rawValue: rawValue) ?? .automatic
    }
}

/// Quale valore mettere in grande nel widget.
enum WidgetMetricEntity: String, AppEnum {
    case automatic
    case daily
    case weekly
    case monthly
    case total

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Mostra in evidenza"

    static var caseDisplayRepresentations: [WidgetMetricEntity: DisplayRepresentation] = [
        .automatic: DisplayRepresentation(
            title: "Automatico",
            subtitle: "Credito residuo, se disponibile"
        ),
        .daily: DisplayRepresentation(title: "Spesa di oggi"),
        .weekly: DisplayRepresentation(title: "Spesa della settimana"),
        .monthly: DisplayRepresentation(title: "Spesa del mese"),
        .total: DisplayRepresentation(title: "Spesa totale"),
    ]

    var metric: WidgetMetric {
        WidgetMetric(rawValue: rawValue) ?? .automatic
    }
}

struct CreditsWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Crediti OpenRouter"
    static var description = IntentDescription("Mostra i crediti disponibili su OpenRouter.")

    @Parameter(title: "Schema colori", default: .automatic)
    var style: WidgetStyleEntity

    @Parameter(
        title: "Mostra in evidenza",
        description: "Quale valore mettere in grande.",
        default: .automatic
    )
    var metric: WidgetMetricEntity

    @Parameter(
        title: "Grafico 24 ore",
        description: "Mostra l'andamento nel widget medio.",
        default: true
    )
    var showChart: Bool

    @Parameter(
        title: "Mostra i centesimi",
        description: "Se disattivato, gli importi sono arrotondati.",
        default: true
    )
    var showCents: Bool

    var options: CreditsWidgetOptions {
        CreditsWidgetOptions(
            metric: metric.metric,
            showChart: showChart,
            showCents: showCents
        )
    }
}