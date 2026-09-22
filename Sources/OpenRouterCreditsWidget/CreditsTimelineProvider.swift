import OpenRouterCreditsCore
import OpenRouterCreditsUI
import WidgetKit

struct CreditsEntry: TimelineEntry {
    let date: Date
    let style: WidgetStyleOption
    let options: CreditsWidgetOptions
    let snapshot: CreditsSnapshot?
    let history: [StoredState.Sample]
    let lastError: String?
    let isConfigured: Bool
}

extension CreditsEntry {
    /// Dati di esempio usati per l'anteprima nella galleria widget.
    static func placeholder(
        style: WidgetStyleOption = .automatic,
        options: CreditsWidgetOptions = .default
    ) -> CreditsEntry {
        let now = Date()
        let snapshot = CreditsSnapshot(
            updatedAt: now.addingTimeInterval(-90),
            accountRemaining: 12.4,
            accountTotal: 20,
            accountUsage: 7.6,
            keyLimit: 20,
            keyLimitRemaining: 12.4,
            keyUsage: 7.6,
            usageDaily: 0.42,
            usageWeekly: 1.87,
            usageMonthly: 5.31,
            keyLabel: "widget",
            isFreeTier: false,
            freeRequestsRemaining: 1000
        )
        return CreditsEntry(
            date: now,
            style: style,
            options: options,
            snapshot: snapshot,
            history: sampleHistory(endingAt: now),
            lastError: nil,
            isConfigured: true
        )
    }

    private static func sampleHistory(endingAt now: Date) -> [StoredState.Sample] {
        let values: [Double] = [
            15.20, 15.05, 14.92, 14.88, 14.61, 14.40, 14.35, 14.10,
            13.95, 13.80, 13.72, 13.44, 13.30, 13.18, 12.99, 12.86,
            12.75, 12.71, 12.60, 12.58, 12.52, 12.47, 12.44, 12.40,
        ]
        let step = 3600.0
        return values.enumerated().map { index, value in
            StoredState.Sample(
                date: now.addingTimeInterval(-step * Double(values.count - 1 - index)),
                value: value
            )
        }
    }
}

struct CreditsTimelineProvider: AppIntentTimelineProvider {
    private let store = SharedStore.shared
    private let client = OpenRouterClient()

    /// Intervallo di aggiornamento richiesto a WidgetKit.
    static let refreshInterval: TimeInterval = 5 * 60

    func placeholder(in context: Context) -> CreditsEntry {
        .placeholder()
    }

    func snapshot(for configuration: CreditsWidgetIntent, in context: Context) async -> CreditsEntry {
        if context.isPreview {
            return .placeholder(style: configuration.style.option, options: configuration.options)
        }
        return await load(style: configuration.style.option, options: configuration.options)
    }

    func timeline(for configuration: CreditsWidgetIntent, in context: Context) async -> Timeline<CreditsEntry> {
        let entry = await load(style: configuration.style.option, options: configuration.options)
        let next = Date().addingTimeInterval(Self.refreshInterval)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func load(style: WidgetStyleOption, options: CreditsWidgetOptions) async -> CreditsEntry {
        let config = store.loadConfig()

        guard config.hasCredentials else {
            let state = store.loadState()
            return CreditsEntry(
                date: Date(),
                style: style,
                options: options,
                snapshot: state.snapshot,
                history: state.history,
                lastError: nil,
                isConfigured: false
            )
        }

        do {
            let result = try await client.fetchSnapshot(config: config)
            store.record(result.snapshot, error: result.warnings.first)
            return CreditsEntry(
                date: Date(),
                style: style,
                options: options,
                snapshot: result.snapshot,
                history: store.loadState().history,
                lastError: result.warnings.first,
                isConfigured: true
            )
        } catch {
            let message = (error as? OpenRouterError)?.shortDescription ?? Strings.text("Nessuna connessione")
            store.recordFailure(message)
            let state = store.loadState()
            return CreditsEntry(
                date: Date(),
                style: style,
                options: options,
                snapshot: state.snapshot,
                history: state.history,
                lastError: message,
                isConfigured: true
            )
        }
    }
}