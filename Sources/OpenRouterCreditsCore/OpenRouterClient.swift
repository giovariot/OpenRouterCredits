import Foundation

public enum OpenRouterError: Error, Equatable, Sendable {
    case missingCredentials
    case unauthorized
    case forbidden(String)
    case http(Int, String)
    case invalidResponse
    case transport(String)

    /// Messaggio breve, adatto a un widget.
    public var shortDescription: String {
        switch self {
        case .missingCredentials:
            return Strings.text("Nessuna chiave configurata")
        case .unauthorized:
            return Strings.text("Chiave non valida")
        case .forbidden(let message):
            return message.isEmpty ? Strings.text("Permessi insufficienti") : message
        case .http(let code, _):
            return Strings.text("Errore HTTP %d", Int32(code))
        case .invalidResponse:
            return Strings.text("Risposta non valida")
        case .transport:
            return Strings.text("Nessuna connessione")
        }
    }

    /// Spiegazione estesa, per l'app.
    public var longDescription: String {
        switch self {
        case .missingCredentials:
            return Strings.text("Inserisci almeno una chiave API di OpenRouter.")
        case .unauthorized:
            return Strings.text("OpenRouter ha rifiutato la chiave: controlla che sia corretta e attiva.")
        case .forbidden(let message):
            return message.isEmpty
                ? Strings.text("La chiave non ha i permessi necessari per questa operazione.")
                : message
        case .http(let code, let message):
            return message.isEmpty
                ? Strings.text("OpenRouter ha risposto con un errore HTTP %d.", Int32(code))
                : message
        case .invalidResponse:
            return Strings.text("OpenRouter ha restituito una risposta in un formato inatteso.")
        case .transport(let message):
            return Strings.text("Impossibile contattare OpenRouter: %@", message)
        }
    }
}

/// Client minimale per le API dei crediti di OpenRouter.
public struct OpenRouterClient: Sendable {
    public struct KeyInfo: Equatable, Sendable {
        public var label: String?
        public var limit: Double?
        public var limitRemaining: Double?
        public var usage: Double?
        public var usageDaily: Double?
        public var usageWeekly: Double?
        public var usageMonthly: Double?
        public var isFreeTier: Bool?
        public var freeRequestsRemaining: Int?
    }

    public struct AccountCredits: Equatable, Sendable {
        public var totalCredits: Double
        public var totalUsage: Double
        public var remaining: Double { totalCredits - totalUsage }
    }

    /// Esito di un aggiornamento: l'istantanea più eventuali avvisi non fatali
    /// (per esempio la chiave di gestione non valida mentre quella API funziona).
    public struct FetchResult: Equatable, Sendable {
        public var snapshot: CreditsSnapshot
        public var warnings: [String]

        public init(snapshot: CreditsSnapshot, warnings: [String] = []) {
            self.snapshot = snapshot
            self.warnings = warnings
        }
    }

    private let baseURL: URL
    private let session: URLSession

    public init(
        baseURL: URL = URL(string: "https://openrouter.ai/api/v1")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Endpoint

    public func fetchKeyInfo(apiKey: String) async throws -> KeyInfo {
        let data = try await get("key", bearer: apiKey)
        return try Self.decodeKeyInfo(data)
    }

    public func fetchAccountCredits(managementKey: String) async throws -> AccountCredits {
        let data = try await get("credits", bearer: managementKey)
        return try Self.decodeAccountCredits(data)
    }

    /// Unisce `GET /credits` (se è disponibile una chiave di gestione) e
    /// `GET /key` (chiave API standard) in una sola istantanea.
    public func fetchSnapshot(config: AppConfig, now: Date = Date()) async throws -> FetchResult {
        let apiKey = config.trimmedAPIKey
        let managementKey = config.trimmedManagementKey

        guard apiKey != nil || managementKey != nil else {
            throw OpenRouterError.missingCredentials
        }

        var snapshot = CreditsSnapshot(updatedAt: now)
        var warnings: [String] = []
        var failures: [OpenRouterError] = []

        if let managementKey {
            do {
                let account = try await fetchAccountCredits(managementKey: managementKey)
                snapshot.accountTotal = account.totalCredits
                snapshot.accountUsage = account.totalUsage
                snapshot.accountRemaining = account.remaining
            } catch let error as OpenRouterError {
                failures.append(error)
                if case .forbidden = error {
                    warnings.append(Strings.text("Serve una chiave di gestione per il saldo del conto"))
                } else if case .unauthorized = error {
                    warnings.append(Strings.text("Chiave di gestione non valida"))
                }
            }
        }

        if let apiKey {
            do {
                let key = try await fetchKeyInfo(apiKey: apiKey)
                snapshot.keyLabel = key.label
                snapshot.keyLimit = key.limit
                snapshot.keyLimitRemaining = key.limitRemaining
                snapshot.keyUsage = key.usage
                snapshot.usageDaily = key.usageDaily
                snapshot.usageWeekly = key.usageWeekly
                snapshot.usageMonthly = key.usageMonthly
                snapshot.isFreeTier = key.isFreeTier
                snapshot.freeRequestsRemaining = key.freeRequestsRemaining
            } catch let error as OpenRouterError {
                failures.append(error)
            }
        }

        if snapshot.source == .none {
            throw failures.first ?? OpenRouterError.invalidResponse
        }

        return FetchResult(snapshot: snapshot, warnings: warnings + failures.map(\.shortDescription))
    }

    // MARK: - HTTP

    private func get(_ path: String, bearer: String) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("OpenRouterCreditsWidget/1.0 (macOS)", forHTTPHeaderField: "X-Title")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OpenRouterError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw OpenRouterError.invalidResponse
        }

        switch http.statusCode {
        case 200..<300:
            return data
        case 401:
            throw OpenRouterError.unauthorized
        case 403:
            throw OpenRouterError.forbidden(Self.errorMessage(from: data) ?? "Permessi insufficienti")
        default:
            throw OpenRouterError.http(http.statusCode, Self.errorMessage(from: data) ?? "")
        }
    }

    // MARK: - Decodifica

    struct KeyPayload: Decodable {
        struct Data: Decodable {
            var label: String?
            var limit: Double?
            var limit_remaining: Double?
            var usage: Double?
            var usage_daily: Double?
            var usage_weekly: Double?
            var usage_monthly: Double?
            var is_free_tier: Bool?
            var free_model_daily_requests: FreeModelRequests?
        }
        struct FreeModelRequests: Decodable {
            var remaining: Int?
        }
        var data: Data
    }

    struct CreditsPayload: Decodable {
        struct Data: Decodable {
            var total_credits: Double
            var total_usage: Double
        }
        var data: Data
    }

    struct ErrorPayload: Decodable {
        struct ErrorBody: Decodable {
            var code: Int?
            var message: String?
        }
        var error: ErrorBody?
    }

    static func decodeKeyInfo(_ data: Data) throws -> KeyInfo {
        let payload: KeyPayload
        do {
            payload = try JSONDecoder().decode(KeyPayload.self, from: data)
        } catch {
            throw OpenRouterError.invalidResponse
        }
        let d = payload.data
        return KeyInfo(
            label: d.label,
            limit: d.limit,
            limitRemaining: d.limit_remaining,
            usage: d.usage,
            usageDaily: d.usage_daily,
            usageWeekly: d.usage_weekly,
            usageMonthly: d.usage_monthly,
            isFreeTier: d.is_free_tier,
            freeRequestsRemaining: d.free_model_daily_requests?.remaining
        )
    }

    static func decodeAccountCredits(_ data: Data) throws -> AccountCredits {
        let payload: CreditsPayload
        do {
            payload = try JSONDecoder().decode(CreditsPayload.self, from: data)
        } catch {
            throw OpenRouterError.invalidResponse
        }
        return AccountCredits(totalCredits: payload.data.total_credits, totalUsage: payload.data.total_usage)
    }

    static func errorMessage(from data: Data) -> String? {
        guard let payload = try? JSONDecoder().decode(ErrorPayload.self, from: data) else { return nil }
        return payload.error?.message
    }
}