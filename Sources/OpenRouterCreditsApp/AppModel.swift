import AppKit
import Observation
import OpenRouterCreditsCore
import OpenRouterCreditsUI
import SwiftUI
import WidgetKit

@MainActor
@Observable
final class AppModel {
    /// Ogni quanto l'app ricontrolla i crediti mentre è aperta.
    static let refreshInterval: TimeInterval = 4 * 60

    var config: AppConfig
    var state: StoredState
    var apiKeyInput: String
    var managementKeyInput: String
    var statusMessage: String?
    var statusIsError = false
    var isRefreshing = false
    var launchAtLogin: Bool
    var isRegisteringWidget = false

    private let store = SharedStore.shared
    private let client = OpenRouterClient()
    private var timer: Timer?

    init() {
        let config = store.loadConfig()
        self.config = config
        self.state = store.loadState()
        self.apiKeyInput = config.apiKey ?? ""
        self.managementKeyInput = config.managementKey ?? ""
        self.launchAtLogin = LaunchAtLogin.isEnabled
    }

    var snapshot: CreditsSnapshot? { state.snapshot }

    /// Cartella condivisa tra app e widget (mostrata nelle preferenze).
    var storagePath: String {
        let path = store.directory.path
        if let range = path.range(of: "/Library/Group Containers/") {
            return "~" + path[range.lowerBound...]
        }
        return path
    }

    var metrics: WidgetMetrics? {
        guard let snapshot else { return nil }
        let model = CreditsWidgetModel(
            size: .medium,
            style: config.defaultStyle,
            snapshot: snapshot,
            history: state.history,
            lastError: state.lastError,
            isConfigured: config.hasCredentials,
            now: Date()
        )
        return WidgetMetrics.build(from: model)
    }

    func onAppear() {
        launchAtLogin = LaunchAtLogin.isEnabled
        startTimer()
        Task { await refresh() }
    }

    // MARK: - Credenziali

    func saveCredentials() {
        config.apiKey = Self.clean(apiKeyInput)
        config.managementKey = Self.clean(managementKeyInput)
        apiKeyInput = config.apiKey ?? ""
        managementKeyInput = config.managementKey ?? ""
        guard store.saveConfig(config) else {
            statusMessage = Strings.text("Impossibile salvare le chiavi nel contenitore condiviso: l'app non ha una firma valida per l'app group. Esegui scripts/resign.sh sul tuo Mac.")
            statusIsError = true
            return
        }
        statusMessage = config.hasCredentials ? Strings.text("Chiavi salvate.") : Strings.text("Chiavi rimosse.")
        statusIsError = false
        reloadWidgets()
        Task { await refresh() }
    }

    func setDefaultStyle(_ style: WidgetStyleOption) {
        config.defaultStyle = style
        store.saveConfig(config)
        reloadWidgets()
    }

    // MARK: - Aggiornamento

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let saved = store.loadConfig()
        guard saved.hasCredentials else {
            if config.hasCredentials {
                statusMessage = Strings.text("Impossibile salvare le chiavi nel contenitore condiviso: l'app non ha una firma valida per l'app group. Esegui scripts/resign.sh sul tuo Mac.")
                statusIsError = true
                return
            }
            statusMessage = nil
            statusIsError = false
            state = store.loadState()
            return
        }

        do {
            let result = try await client.fetchSnapshot(config: saved)
            store.record(result.snapshot, error: result.warnings.first)
            state = store.loadState()
            if let warning = result.warnings.first {
                statusMessage = warning
                statusIsError = true
            } else {
                statusMessage = Strings.text("Crediti aggiornati.")
                statusIsError = false
            }
            reloadWidgets()
        } catch {
            let short = (error as? OpenRouterError)?.shortDescription ?? "Errore"
            let long = (error as? OpenRouterError)?.longDescription ?? error.localizedDescription
            store.recordFailure(short)
            state = store.loadState()
            statusMessage = long
            statusIsError = true
        }
    }

    // MARK: - Opzioni

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.set(enabled)
            launchAtLogin = LaunchAtLogin.isEnabled
            statusMessage = launchAtLogin
                ? Strings.text("L'app si avvierà all'accesso.")
                : Strings.text("Avvio automatico disattivato.")
            statusIsError = false
        } catch {
            launchAtLogin = LaunchAtLogin.isEnabled
            statusMessage = Strings.text("Impossibile cambiare l'avvio automatico: %@", error.localizedDescription)
            statusIsError = true
        }
    }

    func registerWidget() {
        guard !isRegisteringWidget else { return }
        isRegisteringWidget = true
        Task {
            let outcome = await WidgetRegistration.run()
            isRegisteringWidget = false
            switch outcome {
            case .registered:
                statusMessage = Strings.text("Widget registrato: ora lo trovi in «Modifica widget…».")
                statusIsError = false
            case .pending:
                statusMessage = Strings.text("Registrazione eseguita, ma macOS non mostra ancora il widget. Riprova tra qualche secondo o riavvia il Mac.")
                statusIsError = true
            case .quarantined(let command):
                statusMessage = Strings.text("L'app è ancora in quarantena e non posso toglierla da qui. Nel Terminale esegui: %@", command)
                statusIsError = true
            }
        }
    }

    func openCreditsPage() {
        if let url = URL(string: "https://openrouter.ai/settings/credits") {
            NSWorkspace.shared.open(url)
        }
    }

    func openKeysPage() {
        if let url = URL(string: "https://openrouter.ai/settings/keys") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetConstants.kind)
    }

    private static func clean(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}