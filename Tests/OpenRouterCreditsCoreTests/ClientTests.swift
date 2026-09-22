import Foundation
import XCTest
@testable import OpenRouterCreditsCore

final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (status: Int, body: Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, body) = handler(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class ClientTests: XCTestCase {
    private let keyJSON = """
    {"data":{"label":"sk-or-v1-abc","limit":25.0,"limit_reset":null,"limit_remaining":18.3,
    "include_byok_in_limit":false,"usage":6.7,"usage_daily":0.18,"usage_weekly":0.94,
    "usage_monthly":3.02,"byok_usage":0,"is_free_tier":false,
    "free_model_daily_requests":{"used":0,"limit":1000,"remaining":1000}}}
    """

    private let creditsJSON = """
    {"data":{"total_credits":100.5,"total_usage":25.75}}
    """

    private func makeClient(handler: @escaping (URLRequest) -> (status: Int, body: Data)) -> OpenRouterClient {
        StubURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return OpenRouterClient(session: URLSession(configuration: configuration))
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testDecodesKeyInfo() throws {
        let info = try OpenRouterClient.decodeKeyInfo(Data(keyJSON.utf8))
        XCTAssertEqual(info.label, "sk-or-v1-abc")
        XCTAssertEqual(info.limit, 25)
        XCTAssertEqual(info.limitRemaining, 18.3)
        XCTAssertEqual(info.usage, 6.7)
        XCTAssertEqual(info.usageDaily, 0.18)
        XCTAssertEqual(info.usageWeekly, 0.94)
        XCTAssertEqual(info.usageMonthly, 3.02)
        XCTAssertEqual(info.isFreeTier, false)
        XCTAssertEqual(info.freeRequestsRemaining, 1000)
    }

    func testDecodesUnlimitedKey() throws {
        let json = """
        {"data":{"label":"x","limit":null,"limit_remaining":null,"usage":12.5,"is_free_tier":true}}
        """
        let info = try OpenRouterClient.decodeKeyInfo(Data(json.utf8))
        XCTAssertNil(info.limit)
        XCTAssertNil(info.limitRemaining)
        XCTAssertEqual(info.usage, 12.5)
    }

    func testDecodesAccountCredits() throws {
        let credits = try OpenRouterClient.decodeAccountCredits(Data(creditsJSON.utf8))
        XCTAssertEqual(credits.totalCredits, 100.5)
        XCTAssertEqual(credits.totalUsage, 25.75)
        XCTAssertEqual(credits.remaining, 74.75, accuracy: 0.0001)
    }

    func testFetchSnapshotMergesAccountAndKey() async throws {
        let client = makeClient { request in
            if request.url?.path.hasSuffix("/credits") == true {
                return (200, Data(self.creditsJSON.utf8))
            }
            return (200, Data(self.keyJSON.utf8))
        }

        let config = AppConfig(apiKey: "sk-or-v1-abc", managementKey: "sk-or-v1-mgmt")
        let result = try await client.fetchSnapshot(config: config)

        XCTAssertEqual(result.snapshot.accountRemaining ?? 0, 74.75, accuracy: 0.0001)
        XCTAssertEqual(result.snapshot.keyLimitRemaining, 18.3)
        XCTAssertEqual(result.snapshot.displayRemaining ?? 0, 74.75, accuracy: 0.0001)
        XCTAssertEqual(result.snapshot.source, .account)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testFetchSnapshotKeepsKeyDataWhenManagementKeyIsForbidden() async throws {
        let forbidden = """
        {"error":{"code":403,"message":"Only management keys can perform this operation"}}
        """
        let client = makeClient { request in
            if request.url?.path.hasSuffix("/credits") == true {
                return (403, Data(forbidden.utf8))
            }
            return (200, Data(self.keyJSON.utf8))
        }

        let config = AppConfig(apiKey: "sk-or-v1-abc", managementKey: "sk-or-v1-normal")
        let result = try await client.fetchSnapshot(config: config)

        XCTAssertNil(result.snapshot.accountRemaining)
        XCTAssertEqual(result.snapshot.keyLimitRemaining, 18.3)
        XCTAssertEqual(result.snapshot.source, .keyLimit)
        XCTAssertEqual(result.warnings.first, "Serve una chiave di gestione per il saldo del conto")
    }

    func testFetchSnapshotThrowsUnauthorized() async {
        let unauthorized = """
        {"error":{"code":401,"message":"Invalid credentials"}}
        """
        let client = makeClient { _ in (401, Data(unauthorized.utf8)) }
        let config = AppConfig(apiKey: "sk-or-v1-wrong")

        do {
            _ = try await client.fetchSnapshot(config: config)
            XCTFail("doveva fallire")
        } catch let error as OpenRouterError {
            XCTAssertEqual(error, .unauthorized)
            XCTAssertEqual(error.shortDescription, "Chiave non valida")
        } catch {
            XCTFail("errore inatteso: \(error)")
        }
    }

    func testFetchSnapshotRequiresCredentials() async {
        let client = makeClient { _ in (200, Data()) }
        do {
            _ = try await client.fetchSnapshot(config: AppConfig())
            XCTFail("doveva fallire")
        } catch let error as OpenRouterError {
            XCTAssertEqual(error, .missingCredentials)
        } catch {
            XCTFail("errore inatteso: \(error)")
        }
    }

    func testFetchSnapshotSurfacesHTTPErrors() async {
        let client = makeClient { _ in (500, Data("{}".utf8)) }
        let config = AppConfig(apiKey: "sk-or-v1-abc")
        do {
            _ = try await client.fetchSnapshot(config: config)
            XCTFail("doveva fallire")
        } catch let error as OpenRouterError {
            XCTAssertEqual(error, .http(500, ""))
            XCTAssertEqual(error.shortDescription, "Errore HTTP 500")
        } catch {
            XCTFail("errore inatteso: \(error)")
        }
    }
}