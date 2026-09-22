import Foundation

/// Costanti condivise tra app ed estensione widget.
public enum WidgetConstants {
    /// Identificatore del widget (`kind`), usato per ricaricare le timeline.
    public static let kind = "OpenRouterCreditsWidget"
    /// Schema URL che riapre l'app quando si tocca il widget.
    public static let openURL = "openroutercredits://open"
}

/// Le due varianti colore del brand OpenRouter — "giorno" (bianco e viola) e
/// "notte" (nero e verde) — più la modalità automatica che segue l'aspetto di
/// sistema.
public enum WidgetStyleOption: String, Codable, CaseIterable, Sendable {
    case automatic
    case whitePurple
    case blackGreen

    public var displayName: String {
        switch self {
        case .automatic: return Strings.text("Automatico")
        case .whitePurple: return Strings.text("Giorno")
        case .blackGreen: return Strings.text("Notte")
        }
    }
}

/// Quale valore mettere in evidenza nel widget.
public enum WidgetMetric: String, Codable, CaseIterable, Sendable {
    /// Credito residuo se disponibile, altrimenti la spesa.
    case automatic
    case daily
    case weekly
    case monthly
    case total
}

/// Le scelte fatte dall'utente nel pannello "Modifica widget".
public struct CreditsWidgetOptions: Codable, Equatable, Sendable {
    public var metric: WidgetMetric
    /// Mostra il grafico dell'andamento nel widget medio.
    public var showChart: Bool
    /// Mostra i centesimi negli importi.
    public var showCents: Bool

    public init(metric: WidgetMetric = .automatic, showChart: Bool = true, showCents: Bool = true) {
        self.metric = metric
        self.showChart = showChart
        self.showCents = showCents
    }

    public static let `default` = CreditsWidgetOptions()
}

/// Da dove arriva il numero mostrato come "crediti disponibili".
public enum CreditsSource: String, Codable, Sendable {
    /// Saldo del conto (`GET /credits`, richiede una chiave di gestione).
    case account
    /// Credito residuo del limite impostato sulla chiave (`GET /key`).
    case keyLimit
    /// Nessun limite: si può mostrare solo la spesa accumulata (`GET /key`).
    case keyUsage
    case none
}

/// Istantanea dei crediti letta dalle API di OpenRouter.
public struct CreditsSnapshot: Codable, Equatable, Sendable {
    /// Saldo del conto: `total_credits - total_usage` da `GET /credits`.
    public var accountRemaining: Double?
    public var accountTotal: Double?
    public var accountUsage: Double?

    /// Dati della chiave API da `GET /key`.
    public var keyLimit: Double?
    public var keyLimitRemaining: Double?
    public var keyUsage: Double?
    public var usageDaily: Double?
    public var usageWeekly: Double?
    public var usageMonthly: Double?
    public var keyLabel: String?
    public var isFreeTier: Bool?
    public var freeRequestsRemaining: Int?

    public var updatedAt: Date

    public init(
        updatedAt: Date = Date(),
        accountRemaining: Double? = nil,
        accountTotal: Double? = nil,
        accountUsage: Double? = nil,
        keyLimit: Double? = nil,
        keyLimitRemaining: Double? = nil,
        keyUsage: Double? = nil,
        usageDaily: Double? = nil,
        usageWeekly: Double? = nil,
        usageMonthly: Double? = nil,
        keyLabel: String? = nil,
        isFreeTier: Bool? = nil,
        freeRequestsRemaining: Int? = nil
    ) {
        self.updatedAt = updatedAt
        self.accountRemaining = accountRemaining
        self.accountTotal = accountTotal
        self.accountUsage = accountUsage
        self.keyLimit = keyLimit
        self.keyLimitRemaining = keyLimitRemaining
        self.keyUsage = keyUsage
        self.usageDaily = usageDaily
        self.usageWeekly = usageWeekly
        self.usageMonthly = usageMonthly
        self.keyLabel = keyLabel
        self.isFreeTier = isFreeTier
        self.freeRequestsRemaining = freeRequestsRemaining
    }

    /// Il numero da mostrare in evidenza: prima il saldo del conto, poi il
    /// credito residuo del limite della chiave.
    public var displayRemaining: Double? {
        accountRemaining ?? keyLimitRemaining
    }

    /// Il totale rispetto a cui calcolare la barra di avanzamento.
    public var displayTotal: Double? {
        if accountRemaining != nil {
            return accountTotal
        }
        return keyLimit
    }

    public var source: CreditsSource {
        if accountRemaining != nil {
            return .account
        }
        if keyLimitRemaining != nil {
            return .keyLimit
        }
        if keyUsage != nil {
            return .keyUsage
        }
        return .none
    }

    /// Frazione di credito residuo (0...1) se totale e residuo sono noti.
    public var remainingFraction: Double? {
        guard let total = displayTotal, total > 0, let remaining = displayRemaining else { return nil }
        return min(max(remaining / total, 0), 1)
    }
}

/// Configurazione scritta dall'app e letta anche dall'estensione widget.
public struct AppConfig: Codable, Equatable, Sendable {
    /// Chiave API standard (`sk-or-...`), usata con `GET /api/v1/key`.
    public var apiKey: String?
    /// Chiave di gestione, opzionale, usata con `GET /api/v1/credits`
    /// per conoscere il saldo del conto.
    public var managementKey: String?
    public var defaultStyle: WidgetStyleOption

    public init(apiKey: String? = nil, managementKey: String? = nil, defaultStyle: WidgetStyleOption = .automatic) {
        self.apiKey = apiKey
        self.managementKey = managementKey
        self.defaultStyle = defaultStyle
    }

    public var trimmedAPIKey: String? { Self.clean(apiKey) }
    public var trimmedManagementKey: String? { Self.clean(managementKey) }

    public var hasCredentials: Bool {
        trimmedAPIKey != nil || trimmedManagementKey != nil
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Stato condiviso: ultima istantanea, ultimo errore e storico per lo sparkline.
public struct StoredState: Codable, Equatable, Sendable {
    public struct Sample: Codable, Equatable, Sendable {
        public var date: Date
        public var value: Double

        public init(date: Date, value: Double) {
            self.date = date
            self.value = value
        }
    }

    public var snapshot: CreditsSnapshot?
    public var lastError: String?
    public var history: [Sample]

    public init(snapshot: CreditsSnapshot? = nil, lastError: String? = nil, history: [Sample] = []) {
        self.snapshot = snapshot
        self.lastError = lastError
        self.history = history
    }

    public static let empty = StoredState()
}