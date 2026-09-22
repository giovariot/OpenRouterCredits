import Foundation
import XCTest
@testable import OpenRouterCreditsCore
@testable import OpenRouterCreditsUI

final class MetricsTests: XCTestCase {
    private let now = Date()

    private func model(snapshot: CreditsSnapshot?, lastError: String? = nil, isConfigured: Bool = true) -> CreditsWidgetModel {
        CreditsWidgetModel(
            size: .medium,
            style: .automatic,
            snapshot: snapshot,
            history: [],
            lastError: lastError,
            isConfigured: isConfigured,
            now: now
        )
    }

    func testAccountSnapshotPrefersAccountBalance() {
        let snapshot = CreditsSnapshot(
            updatedAt: now,
            accountRemaining: 12.4,
            accountTotal: 20,
            keyLimit: 20,
            keyLimitRemaining: 5,
            keyUsage: 15
        )
        let metrics = WidgetMetrics.build(from: model(snapshot: snapshot))
        XCTAssertEqual(metrics.kind, .remaining)
        XCTAssertEqual(metrics.heroValue ?? 0, 12.4, accuracy: 0.0001)
        XCTAssertEqual(metrics.caption, "credito residuo")
        XCTAssertEqual(metrics.detail, "di \(Format.money(20)) totali")
        XCTAssertEqual(metrics.fraction ?? 0, 0.62, accuracy: 0.0001)
    }

    func testKeyLimitSnapshot() {
        let snapshot = CreditsSnapshot(updatedAt: now, keyLimit: 25, keyLimitRemaining: 18.3, keyUsage: 6.7)
        let metrics = WidgetMetrics.build(from: model(snapshot: snapshot))
        XCTAssertEqual(metrics.kind, .remaining)
        XCTAssertEqual(metrics.caption, "rimasti sulla chiave")
        XCTAssertEqual(metrics.detail, "limite \(Format.money(25))")
        XCTAssertEqual(metrics.fraction ?? 0, 0.732, accuracy: 0.001)
    }

    func testUnlimitedKeyShowsUsage() {
        let snapshot = CreditsSnapshot(updatedAt: now, keyUsage: 42.19, usageDaily: 1.24)
        let metrics = WidgetMetrics.build(from: model(snapshot: snapshot))
        XCTAssertEqual(metrics.kind, .usage)
        XCTAssertEqual(metrics.heroValue ?? 0, 42.19, accuracy: 0.0001)
        XCTAssertEqual(metrics.caption, "spesa totale")
        XCTAssertNil(metrics.fraction)
        XCTAssertEqual(metrics.dailyText, "Oggi \(Format.money(1.24))")
    }

    func testNotConfiguredState() {
        let metrics = WidgetMetrics.build(from: model(snapshot: nil, isConfigured: false))
        XCTAssertTrue(metrics.isEmpty)
        XCTAssertEqual(metrics.caption, "Configura l'app")
        XCTAssertEqual(metrics.detail, "Inserisci la chiave API di OpenRouter")
    }

    func testStaleDataShowsError() {
        let snapshot = CreditsSnapshot(updatedAt: now.addingTimeInterval(-600), accountRemaining: 1, accountTotal: 2)
        let metrics = WidgetMetrics.build(from: model(snapshot: snapshot, lastError: "Nessuna connessione"))
        XCTAssertEqual(metrics.updatedText, "Non aggiornato · 10 min fa")
    }

    func testMoneyFormatting() {
        // I valori sono racchiusi tra marcatori di direzione (LRI…PDI) così
        // restano corretti anche in arabo e urdu.
        XCTAssertEqual(Format.money(12.4), "\u{2066}$12.40\u{2069}")
        XCTAssertEqual(Format.money(0), "\u{2066}$0.00\u{2069}")
        XCTAssertEqual(Format.money(12_345), "\u{2066}$12.3K\u{2069}")
        XCTAssertEqual(Format.money(nil), "\u{2066}$--\u{2069}")
    }

    func testRelativeFormatting() {
        XCTAssertEqual(Format.relative(now.addingTimeInterval(-10), now: now), "ora")
        XCTAssertEqual(Format.relative(now.addingTimeInterval(-120), now: now), "2 min fa")
        XCTAssertEqual(Format.relative(now.addingTimeInterval(-3600 * 3), now: now), "3 h fa")
        XCTAssertEqual(Format.relative(now.addingTimeInterval(-3600 * 30), now: now), "ieri")
    }

    func testPercentFormatting() {
        XCTAssertEqual(Format.percent(0.62), "62%")
        XCTAssertEqual(Format.percent(nil), "--")
    }
}