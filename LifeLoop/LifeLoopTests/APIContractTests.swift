import Foundation
import Testing
@testable import LifeLoop

@MainActor
struct APIContractTests {
    private let server = URL(string: "https://staging.example.com")!
    private let accountID = "00000000-0000-0000-0000-000000000099"

    @Test func googleLoginExchangesIDTokenForLifeLoopCookie() async throws {
        let transport = ContractTransport()
        let store = MemoryCredentials()
        let client = APIClient(baseURL: server, transport: transport, credentials: store)
        transport.handler = { request in
            #expect(request.url?.path == "/api/v1/auth/google")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Cookie") == nil)
            let body = try JSONDecoder().decode([String: String].self, from: #require(request.httpBody))
            #expect(body["credential"] == "google-id-token")
            #expect(body["timezone"] == TimeZone.current.identifier)
            #expect(body["email"] == nil)
            #expect(body["password"] == nil)
            return self.response(self.accountJSON, headers: [
                "Set-Cookie": "session=test-token; Max-Age=604800; Path=/; HttpOnly; Secure; SameSite=None"
            ])
        }
        let account = try await APIAccountRepository(client: client).signIn(
            googleIDToken: "google-id-token"
        )
        #expect(account.id.uuidString.lowercased() == accountID)
        #expect(store.credential?.token == "test-token")
        #expect(store.credential?.account == account)
    }

    @Test func inactiveAccountDoesNotPersistCookie() async throws {
        let store = MemoryCredentials()
        let transport = ContractTransport()
        transport.handler = { _ in
            self.response(self.accountJSON.replacingOccurrences(of: "active", with: "suspended"), headers: [
                "Set-Cookie": "session=test-token; Max-Age=604800; Path=/; Secure"
            ])
        }
        let repository = APIAccountRepository(client: APIClient(baseURL: server, transport: transport, credentials: store))
        await #expect(throws: APIError.self) { try await repository.signIn(googleIDToken: "google-id-token") }
        #expect(store.credential == nil)
    }

    @Test func emptyGoogleTokenNeverReachesServer() async {
        let transport = ContractTransport()
        let repository = APIAccountRepository(client: APIClient(
            baseURL: server, transport: transport, credentials: MemoryCredentials()
        ))
        await #expect(throws: GoogleSignInFailure.self) {
            try await repository.signIn(googleIDToken: "   ")
        }
        #expect(transport.requests.isEmpty)
    }

    @Test func googleLoginWithoutSessionCookieDoesNotSignIn() async {
        let transport = ContractTransport()
        let store = MemoryCredentials()
        transport.handler = { _ in self.response(self.accountJSON) }
        let repository = APIAccountRepository(client: APIClient(
            baseURL: server, transport: transport, credentials: store
        ))
        await #expect(throws: APIError.invalidResponse) {
            try await repository.signIn(googleIDToken: "google-id-token")
        }
        #expect(store.credential == nil)
    }

    @Test func sessionCookieWithoutExpiryIsRejected() async {
        let transport = ContractTransport()
        let store = MemoryCredentials()
        transport.handler = { _ in
            self.response(self.accountJSON, headers: [
                "Set-Cookie": "session=test-token; Path=/; Secure"
            ])
        }
        let repository = APIAccountRepository(client: APIClient(
            baseURL: server, transport: transport, credentials: store
        ))
        await #expect(throws: APIError.invalidResponse) {
            try await repository.signIn(googleIDToken: "google-id-token")
        }
        #expect(store.credential == nil)
    }

    @Test func expiredSessionCookieIsRejected() async {
        let transport = ContractTransport()
        let store = MemoryCredentials()
        transport.handler = { _ in
            self.response(self.accountJSON, headers: [
                "Set-Cookie": "session=test-token; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Path=/; Secure"
            ])
        }
        let repository = APIAccountRepository(client: APIClient(
            baseURL: server, transport: transport, credentials: store
        ))
        await #expect(throws: APIError.invalidResponse) {
            try await repository.signIn(googleIDToken: "google-id-token")
        }
        #expect(store.credential == nil)
    }

    @Test func expiredCredentialsNeverReachTransport() async throws {
        let transport = ContractTransport()
        let store = MemoryCredentials()
        store.credential = SessionCredential(token: "expired", expiresAt: .distantPast)
        let client = APIClient(baseURL: server, transport: transport, credentials: store)
        await #expect(throws: APIError.self) { try await client.request("api/v1/items") }
        #expect(transport.requests.isEmpty)
    }

    @Test func lateResponseAfterLogoutIsRejected() async throws {
        let store = MemoryCredentials()
        store.credential = SessionCredential(token: "account-A", expiresAt: .distantFuture)
        let transport = ContractTransport()
        let client = APIClient(baseURL: server, transport: transport, credentials: store)
        transport.handler = { request in
            #expect(request.value(forHTTPHeaderField: "Cookie") == "session=account-A")
            try client.clearSession()
            return self.response("{\"items\":[]}")
        }
        await #expect(throws: CancellationError.self) { try await client.request("api/v1/items") }
        #expect(store.credential == nil)
    }

    @Test(arguments: [401, 403, 409, 412, 429, 500, 302])
    func httpFailuresDoNotDecodeAsSuccess(status: Int) async throws {
        let transport = ContractTransport()
        transport.handler = { _ in self.response("private server detail", status: status) }
        let client = APIClient(baseURL: server, transport: transport, credentials: MemoryCredentials())
        await #expect(throws: APIError.self) {
            try await client.request("api/v1/auth/google", authenticated: false)
        }
    }

    @Test func metadataAndUnknownTypesSurviveMapping() throws {
        let payload = """
        {"items":[{"id":"00000000-0000-0000-0000-000000000001",
        "title":"An imported record","status":"future_status","itemType":"future_type",
        "dueDate":"2026-11-16T09:30:00.123Z","updatedAt":"revision-as-received",
        "metadata":{"amount":123.45,"future":{"flag":true,"values":[null,"value"]}}}]}
        """
        let item = try JSONDecoder().decode(ItemListResponse.self, from: Data(payload.utf8)).items[0].domainValue()
        #expect(item.status == .unknown("future_status"))
        #expect(item.itemType == "future_type")
        #expect(item.updatedAt == "revision-as-received")
        #expect(item.dueDate != nil)
        #expect(item.metadata["amount"] == .number(Decimal(string: "123.45")!))
        #expect(item.metadata["future"] == .object(["flag": .bool(true), "values": .array([.null, .string("value")])]))
        let roundTrip = try JSONDecoder().decode([String: JSONValue].self, from: JSONEncoder().encode(item.metadata))
        #expect(roundTrip == item.metadata)
    }

    @Test func nullDatesAndMetadataAreAccepted() throws {
        let payload = """
        {"items":[{"id":"00000000-0000-0000-0000-000000000001",
        "title":"No date","status":"active","itemType":"task","dueDate":null,"metadata":null}]}
        """
        let item = try JSONDecoder().decode(ItemListResponse.self, from: Data(payload.utf8)).items[0].domainValue()
        #expect(item.dueDate == nil)
        #expect(item.metadata.isEmpty)
    }

    @Test func unknownConfigurationFailsClosed() {
        #expect(throws: AppConfiguration.ConfigurationError.self) {
            try AppConfiguration(values: ["LifeLoopEnvironment": "typo"])
        }
    }

    // MARK: - P2 Mutation Contract Tests

    @Test(arguments: 0..<5)
    func unverifiedMutationsNeverReachServer(operation: Int) async {
        let transport = ContractTransport()
        let client = APIClient(baseURL: server, transport: transport, credentials: MemoryCredentials())
        let repository = APIItemRepository(client: client)
        await #expect(throws: APIItemRepository.MutationError.self) {
            switch operation {
            case 0: _ = try await repository.createItem(title: "New", itemType: "task")
            case 1: _ = try await repository.updateItem(id: UUID(), title: "Changed", updatedAt: "revision")
            case 2: _ = try await repository.completeItem(id: UUID(), updatedAt: "revision")
            case 3: _ = try await repository.reopenItem(id: UUID(), updatedAt: "revision")
            default: try await repository.deleteItem(id: UUID(), updatedAt: "revision")
            }
        }
        #expect(transport.requests.isEmpty)
    }

    @Test func conflictResponseThrowsAPIErrorConflict() async throws {
        let transport = ContractTransport()
        transport.handler = { _ in self.response("{}", status: 409) }
        let client = APIClient(baseURL: server, transport: transport, credentials: MemoryCredentials())
        let error = await #expect(throws: APIError.self) {
            try await client.request("api/v1/items", authenticated: false)
        }
        #expect(error == .conflict)
    }

    @Test func offlineRestorationRequiresUnexpiredVerifiedAccount() async throws {
        let transport = ContractTransport()
        transport.handler = { _ in throw URLError(.notConnectedToInternet) }
        let store = MemoryCredentials()
        let account = Account(id: UUID(), email: "offline@example.com", accountStatus: "active", isAdmin: false)
        store.credential = SessionCredential(token: "token", expiresAt: .distantFuture, account: account)
        let repository = APIAccountRepository(client: APIClient(baseURL: server, transport: transport, credentials: store))
        #expect(try await repository.currentAccount().id == account.id)
        store.credential = SessionCredential(token: "token", expiresAt: .distantPast, account: account)
        await #expect(throws: APIError.self) { try await repository.currentAccount() }
        #expect(store.credential == nil)
    }

    @Test func revokedAccountCannotFallBackToOfflineIdentity() async throws {
        let transport = ContractTransport()
        transport.handler = { _ in self.response("{}", status: 403) }
        let store = MemoryCredentials()
        store.credential = SessionCredential(token: "token", expiresAt: .distantFuture,
            account: Account(id: UUID(), email: "a@example.com", accountStatus: "active", isAdmin: false))
        let repository = APIAccountRepository(client: APIClient(baseURL: server, transport: transport, credentials: store))
        await #expect(throws: APIError.self) { try await repository.currentAccount() }
        #expect(store.credential == nil)
    }

    private var accountJSON: String {
        "{\"user\":{\"id\":\"\(accountID)\",\"email\":\"reader@example.com\",\"isAdmin\":false,\"accountStatus\":\"active\"}}"
    }

    private func response(_ json: String, status: Int = 200, headers: [String: String] = [:]) -> (Data, HTTPURLResponse) {
        (Data(json.utf8), HTTPURLResponse(url: server, statusCode: status, httpVersion: nil, headerFields: headers)!)
    }
}

@MainActor
private final class MemoryCredentials: SessionCredentialStore {
    var credential: SessionCredential?
    func read() throws -> SessionCredential? { credential }
    func save(_ credential: SessionCredential) throws { self.credential = credential }
    func clear() throws { credential = nil }
}

@MainActor
private final class ContractTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var handler: ((URLRequest) async throws -> (Data, HTTPURLResponse))?
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let respond = try #require(handler)
        return try await respond(request)
    }
}
