import Foundation
import XCTest
@testable import OpenRouterCreditsCore

final class StoreTests: XCTestCase {
    private var directory: URL!
    private var store: SharedStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenRouterCreditsTests-\(UUID().uuidString)", isDirectory: true)
        store = SharedStore(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testConfigRoundTrip() {
        let config = AppConfig(apiKey: "sk-or-v1-abc", managementKey: "mgmt", defaultStyle: .blackGreen)
        store.saveConfig(config)
        XCTAssertEqual(store.loadConfig(), config)
    }

    func testConfigFileIsPrivate() {
        store.saveConfig(AppConfig(apiKey: "sk-or-v1-abc"))
        let attributes = try? FileManager.default.attributesOfItem(atPath: store.configURL.path)
        let permissions = attributes?[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)
    }

    func testMissingConfigReturnsDefaults() {
        XCTAssertEqual(store.loadConfig(), AppConfig())
        XCTAssertEqual(store.loadState(), StoredState.empty)
    }

    func testRecordKeepsHistoryAndPrunesOldSamples() {
        let now = Date()
        let old = CreditsSnapshot(updatedAt: now.addingTimeInterval(-48 * 3600), accountRemaining: 5, accountTotal: 10)
        store.record(old, error: nil)

        let fresh = CreditsSnapshot(updatedAt: now, accountRemaining: 9.5, accountTotal: 10)
        store.record(fresh, error: nil)

        let state = store.loadState()
        XCTAssertEqual(state.history.count, 1, "i campioni più vecchi di 24 ore vengono rimossi")
        XCTAssertEqual(state.history.first?.value, 9.5)
        XCTAssertEqual(state.snapshot?.accountRemaining, 9.5)
        XCTAssertNil(state.lastError)
    }

    func testRecordFailureKeepsLastSnapshot() {
        let snapshot = CreditsSnapshot(updatedAt: Date(), accountRemaining: 3.25, accountTotal: 10)
        store.record(snapshot, error: nil)
        store.recordFailure("Nessuna connessione")

        let state = store.loadState()
        XCTAssertEqual(state.snapshot?.accountRemaining, 3.25)
        XCTAssertEqual(state.lastError, "Nessuna connessione")
    }

    func testUpdateStateIsSerialized() {
        let iterations = 40
        DispatchQueue.concurrentPerform(iterations: iterations) { index in
            store.updateState { state in
                state.history.append(.init(date: Date(), value: Double(index)))
            }
        }
        XCTAssertEqual(store.loadState().history.count, iterations, "nessuna scrittura deve andare persa")
    }
}