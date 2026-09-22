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

struct CreditsWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Crediti OpenRouter"
    static var description = IntentDescription("Mostra i crediti disponibili su OpenRouter.")

    @Parameter(title: "Schema colori", default: .automatic)
    var style: WidgetStyleEntity
}