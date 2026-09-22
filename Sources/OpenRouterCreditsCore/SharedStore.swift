import Darwin
import Foundation

/// Archivio condiviso tra l'app e l'estensione widget.
///
/// Quando il binario è firmato con un app group (il caso normale: l'estensione
/// è sandboxata) si usa il contenitore condiviso `~/Library/Group Containers/…`.
/// Negli altri casi (tool da riga di comando, test, build senza sandbox) si
/// ricade su `~/Library/Application Support/OpenRouterCredits`.
/// L'accesso in scrittura è serializzato con `flock` per evitare corse tra app
/// e widget.
public struct SharedStore: Sendable {
    public static let fallbackDirectory = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/OpenRouterCredits", isDirectory: true)

    public static let defaultDirectory: URL = {
        if let group = SigningInfo.applicationGroupIdentifier,
           let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) {
            return container.appendingPathComponent("OpenRouterCredits", isDirectory: true)
        }
        return fallbackDirectory
    }()

    public static let shared = SharedStore()

    public let directory: URL

    public init(directory: URL = SharedStore.defaultDirectory) {
        self.directory = directory
    }

    public var configURL: URL { directory.appendingPathComponent("config.json") }
    public var stateURL: URL { directory.appendingPathComponent("state.json") }
    private var lockURL: URL { directory.appendingPathComponent(".lock") }

    // MARK: - Configurazione

    public func loadConfig() -> AppConfig {
        guard let data = try? Data(contentsOf: configURL),
              let config = try? Self.decoder.decode(AppConfig.self, from: data) else {
            return AppConfig()
        }
        return config
    }

    public func saveConfig(_ config: AppConfig) {
        guard let data = try? Self.encoder.encode(config) else { return }
        ensureDirectory()
        try? data.write(to: configURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)
    }

    // MARK: - Stato

    public func loadState() -> StoredState {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? Self.decoder.decode(StoredState.self, from: data) else {
            return .empty
        }
        return state
    }

    public func saveState(_ state: StoredState) {
        guard let data = try? Self.encoder.encode(state) else { return }
        ensureDirectory()
        try? data.write(to: stateURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stateURL.path)
    }

    /// Legge, modifica e riscrive lo stato tenendo il lock esclusivo.
    public func updateState(_ mutate: (inout StoredState) -> Void) {
        ensureDirectory()
        let fd = open(lockURL.path, O_CREAT | O_RDWR, 0o600)
        if fd >= 0 { flock(fd, LOCK_EX) }
        defer {
            if fd >= 0 {
                flock(fd, LOCK_UN)
                close(fd)
            }
        }

        var state = loadState()
        mutate(&state)
        saveState(state)
    }

    /// Registra una lettura riuscita (o l'errore che l'ha impedita) e
    /// aggiorna lo storico usato dallo sparkline.
    public func record(_ snapshot: CreditsSnapshot, error: String?) {
        updateState { state in
            state.snapshot = snapshot
            state.lastError = error
            if let value = snapshot.displayRemaining {
                state.history.append(.init(date: snapshot.updatedAt, value: value))
            }
            let cutoff = snapshot.updatedAt.addingTimeInterval(-24 * 3600)
            state.history = state.history.filter { $0.date >= cutoff }
            if state.history.count > 400 {
                state.history.removeFirst(state.history.count - 400)
            }
        }
    }

    /// Registra un errore senza toccare l'ultima istantanea valida.
    public func recordFailure(_ message: String) {
        updateState { state in
            state.lastError = message
        }
    }

    public func clearError() {
        updateState { state in
            state.lastError = nil
        }
    }

    // MARK: - Helper

    private func ensureDirectory() {
        guard !FileManager.default.fileExists(atPath: directory.path) else { return }
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}