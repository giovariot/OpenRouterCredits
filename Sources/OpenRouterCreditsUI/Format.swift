import Foundation
import OpenRouterCreditsCore

/// Formattazione dei valori mostrati nel widget e nell'app.
public enum Format {
    private static let moneyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.currencySymbol = "$"
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let wholeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.currencySymbol = "$"
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    /// `$12.40`, oppure `$--` quando il valore non è noto.
    /// Il valore è racchiuso tra marcatori di direzione così resta corretto
    /// anche nelle lingue da destra a sinistra (arabo, urdu).
    public static func money(_ value: Double?, cents: Bool = true) -> String {
        isolate(amountText(value, cents: cents))
    }

    public static func money(_ value: Double, cents: Bool = true) -> String {
        isolate(amountText(value, cents: cents))
    }

    private static func amountText(_ value: Double?, cents: Bool) -> String {
        guard let value else { return "$--" }
        if value >= 10_000 {
            return "$" + String(format: cents ? "%.1fK" : "%.0fK", value / 1_000)
        }
        let formatter = cents ? moneyFormatter : wholeFormatter
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    /// Isola un tratto di testo da sinistra a destra dentro una frase RTL.
    private static func isolate(_ text: String) -> String {
        "\u{2066}\(text)\u{2069}"
    }

    /// Percentuale intera, per la barra: `42%`.
    public static func percent(_ fraction: Double?) -> String {
        guard let fraction else { return "--" }
        return "\(Int((fraction * 100).rounded()))%"
    }

    /// Tempo relativo: `ora`, `4 min fa`, `3 h fa`, `ieri`, poi la data.
    public static func relative(_ date: Date, now: Date = Date()) -> String {
        let interval = now.timeIntervalSince(date)
        if interval < 60 { return Strings.text("ora") }
        if interval < 3600 { return Strings.text("%d min fa", Int32(interval / 60)) }
        if interval < 24 * 3600 {
            let hours = Int(interval / 3600)
            return hours == 1 ? Strings.text("1 h fa") : Strings.text("%d h fa", Int32(hours))
        }
        if Calendar.current.isDateInYesterday(date) { return Strings.text("ieri") }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// Data estesa per l'app: `22 set 2026, 18:20`.
    public static func full(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}