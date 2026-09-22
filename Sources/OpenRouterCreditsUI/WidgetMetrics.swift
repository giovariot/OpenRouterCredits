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
    public var options: CreditsWidgetOptions
    public var snapshot: CreditsSnapshot?
    public var history: [StoredState.Sample]
    public var lastError: String?
    public var isConfigured: Bool
    public var now: Date

    public init(
        size: Size,
        style: WidgetStyleOption,
        options: CreditsWidgetOptions = .default,
        snapshot: CreditsSnapshot?,
        history: [StoredState.Sample],
        lastError: String?,
        isConfigured: Bool,
        now: Date
    ) {
        self.size = size
        self.style = style
        self.options = options
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
        /// Spesa (di oggi, della settimana, del mese o totale).
        case usage
        case unavailable
    }

    public var kind: Kind
    /// Il valore messo in evidenza, dopo il ripiego sulla modalità automatica.
    public var metric: WidgetMetric
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

    private struct Hero {
        var kind: Kind
        var metric: WidgetMetric
        var value: Double?
        var caption: String
        var detail: String?
        var fraction: Double?
    }

    public static func build(from model: CreditsWidgetModel) -> WidgetMetrics {
        let cents = model.options.showCents

        guard let snapshot = model.snapshot else {
            return WidgetMetrics(
                kind: .unavailable,
                metric: .automatic,
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

        var resolved = resolveHero(for: snapshot, metric: model.options.metric, cents: cents)
        if resolved.value == nil, model.options.metric != .automatic {
            // Il dato scelto non c'è (per esempio una chiave di gestione senza
            // spese giornaliere): si torna alla modalità automatica.
            resolved = resolveHero(for: snapshot, metric: .automatic, cents: cents)
        }

        let updated: String
        let relative = Format.relative(snapshot.updatedAt, now: model.now)
        if model.lastError != nil {
            updated = Strings.text("Non aggiornato · %@", relative)
        } else {
            updated = Strings.text("Aggiornato %@", relative)
        }

        return WidgetMetrics(
            kind: resolved.kind,
            metric: resolved.metric,
            heroValue: resolved.value,
            caption: resolved.caption,
            detail: resolved.detail,
            fraction: resolved.fraction,
            updatedText: updated,
            dailyAmount: snapshot.usageDaily,
            dailyText: snapshot.usageDaily.map { Strings.text("Oggi %@", Format.money($0, cents: cents)) },
            weeklyText: snapshot.usageWeekly.map { Strings.text("Settimana %@", Format.money($0, cents: cents)) },
            monthlyText: snapshot.usageMonthly.map { Strings.text("Mese %@", Format.money($0, cents: cents)) }
        )
    }

    private static func resolveHero(for snapshot: CreditsSnapshot, metric: WidgetMetric, cents: Bool) -> Hero {
        switch metric {
        case .automatic:
            switch snapshot.source {
            case .account:
                return Hero(
                    kind: .remaining,
                    metric: .automatic,
                    value: snapshot.accountRemaining,
                    caption: Strings.text("credito residuo"),
                    detail: snapshot.accountTotal.map { Strings.text("di %@ totali", Format.money($0, cents: cents)) },
                    fraction: snapshot.remainingFraction
                )
            case .keyLimit:
                return Hero(
                    kind: .remaining,
                    metric: .automatic,
                    value: snapshot.keyLimitRemaining,
                    caption: Strings.text("rimasti sulla chiave"),
                    detail: snapshot.keyLimit.map { Strings.text("limite %@", Format.money($0, cents: cents)) },
                    fraction: snapshot.remainingFraction
                )
            case .keyUsage:
                return Hero(
                    kind: .usage,
                    metric: .automatic,
                    value: snapshot.keyUsage,
                    caption: Strings.text("spesa totale"),
                    detail: Strings.text("nessun limite sulla chiave"),
                    fraction: nil
                )
            case .none:
                return Hero(
                    kind: .unavailable,
                    metric: .automatic,
                    value: nil,
                    caption: Strings.text("crediti non disponibili"),
                    detail: Strings.text("Apri l'app per i dettagli"),
                    fraction: nil
                )
            }

        case .daily:
            return Hero(
                kind: .usage,
                metric: .daily,
                value: snapshot.usageDaily,
                caption: Strings.text("spesa di oggi"),
                detail: nil,
                fraction: nil
            )

        case .weekly:
            return Hero(
                kind: .usage,
                metric: .weekly,
                value: snapshot.usageWeekly,
                caption: Strings.text("spesa della settimana"),
                detail: nil,
                fraction: nil
            )

        case .monthly:
            return Hero(
                kind: .usage,
                metric: .monthly,
                value: snapshot.usageMonthly,
                caption: Strings.text("spesa del mese"),
                detail: nil,
                fraction: nil
            )

        case .total:
            return Hero(
                kind: .usage,
                metric: .total,
                value: snapshot.keyUsage ?? snapshot.accountUsage,
                caption: Strings.text("spesa totale"),
                detail: nil,
                fraction: nil
            )
        }
    }
}