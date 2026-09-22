import Foundation
import OpenRouterCreditsCore

/// Tutto ciò che serve a disegnare un widget, senza dipendere da WidgetKit.
public struct CreditsWidgetModel: Equatable {
    public enum Size: Equatable {
        case small
        case medium
    }

    public var size: Size
    public var style: WidgetStyleOption
    public var snapshot: CreditsSnapshot?
    public var history: [StoredState.Sample]
    public var lastError: String?
    public var isConfigured: Bool
    public var now: Date

    public init(
        size: Size,
        style: WidgetStyleOption,
        snapshot: CreditsSnapshot?,
        history: [StoredState.Sample],
        lastError: String?,
        isConfigured: Bool,
        now: Date
    ) {
        self.size = size
        self.style = style
        self.snapshot = snapshot
        self.history = history
        self.lastError = lastError
        self.isConfigured = isConfigured
        self.now = now
    }
}

/// I testi e i numeri già pronti per la vista.
public struct WidgetMetrics: Equatable {
    public enum Kind: Equatable {
        /// Credito residuo (saldo del conto o limite della chiave).
        case remaining
        /// Nessun limite disponibile: si mostra la spesa.
        case usage
        case unavailable
    }

    public var kind: Kind
    public var heroValue: Double?
    public var caption: String
    public var detail: String?
    public var fraction: Double?
    public var updatedText: String?
    public var dailyAmount: Double?
    public var dailyText: String?
    public var weeklyText: String?
    public var monthlyText: String?
    public var isEmpty: Bool { kind == .unavailable }

    public static func build(from model: CreditsWidgetModel) -> WidgetMetrics {
        guard let snapshot = model.snapshot else {
            return WidgetMetrics(
                kind: .unavailable,
                heroValue: nil,
                caption: model.isConfigured
                    ? (model.lastError ?? Strings.text("Nessun dato"))
                    : Strings.text("Configura l'app"),
                detail: model.isConfigured
                    ? Strings.text("Apri l'app per riprovare")
                    : Strings.text("Inserisci la chiave API di OpenRouter"),
                fraction: nil,
                updatedText: nil,
                dailyAmount: nil,
                dailyText: nil,
                weeklyText: nil,
                monthlyText: nil
            )
        }

        let kind: Kind
        let hero: Double?
        let caption: String
        let detail: String?

        switch snapshot.source {
        case .account:
            kind = .remaining
            hero = snapshot.accountRemaining
            caption = Strings.text("credito residuo")
            detail = snapshot.accountTotal.map { Strings.text("di %@ totali", Format.money($0)) }
        case .keyLimit:
            kind = .remaining
            hero = snapshot.keyLimitRemaining
            caption = Strings.text("rimasti sulla chiave")
            detail = snapshot.keyLimit.map { Strings.text("limite %@", Format.money($0)) }
        case .keyUsage:
            kind = .usage
            hero = snapshot.keyUsage
            caption = Strings.text("spesa totale")
            detail = Strings.text("nessun limite sulla chiave")
        case .none:
            kind = .unavailable
            hero = nil
            caption = Strings.text("crediti non disponibili")
            detail = Strings.text("Apri l'app per i dettagli")
        }

        let updated: String
        let relative = Format.relative(snapshot.updatedAt, now: model.now)
        if model.lastError != nil {
            updated = Strings.text("Non aggiornato · %@", relative)
        } else {
            updated = Strings.text("Aggiornato %@", relative)
        }

        return WidgetMetrics(
            kind: kind,
            heroValue: hero,
            caption: caption,
            detail: detail,
            fraction: snapshot.remainingFraction,
            updatedText: updated,
            dailyAmount: snapshot.usageDaily,
            dailyText: snapshot.usageDaily.map { Strings.text("Oggi %@", Format.money($0)) },
            weeklyText: snapshot.usageWeekly.map { Strings.text("Settimana %@", Format.money($0)) },
            monthlyText: snapshot.usageMonthly.map { Strings.text("Mese %@", Format.money($0)) }
        )
    }
}