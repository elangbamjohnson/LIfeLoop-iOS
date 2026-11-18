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

    @Test func decodingItemWithRevision() throws {
        let payload = """
        {"items":[{"id":"00000000-0000-0000-0000-000000000001",
        "title":"Versioned item","status":"active","itemType":"task",
        "dueDate":null,"metadata":null,"revision":4,"updatedAt":"2026-11-17T20:00:00.000Z"}]}
        """
        let item = try JSONDecoder().decode(ItemListResponse.self, from: Data(payload.utf8)).items[0].domainValue()
        #expect(item.revision == 4)
        #expect(item.updatedAt == "2026-11-17T20:00:00.000Z")
    }

    @Test func decodingServerResponseWithoutRevision() throws {
        let payload = """
        {"items":[{"id":"00000000-0000-0000-0000-000000000001",
        "title":"Legacy server item","status":"active","itemType":"task",
        "updatedAt":"2026-11-14T00:00:00.000Z"}]}
        """
        let item = try JSONDecoder().decode(ItemListResponse.self, from: Data(payload.utf8)).items[0].domainValue()
        #expect(item.revision == nil)
        #expect(item.updatedAt == "2026-11-14T00:00:00.000Z")
    }

    @Test func decodingLegacyCachedJSONWithoutRevision() throws {
        let payload = """
        {"id":"00000000-0000-0000-0000-000000000001",
        "title":"Legacy cached item","status":{"active":{}},"itemType":"task",
        "metadata":{},"updatedAt":"2026-11-14T00:00:00.000Z"}
        """
        let item = try JSONDecoder().decode(LifeItem.self, from: Data(payload.utf8))
        #expect(item.revision == nil)
        #expect(item.status == .active)
        #expect(item.updatedAt == "2026-11-14T00:00:00.000Z")
    }

    @Test(arguments: 0..<4)
    func otherConnectedMutationsMakeNoNetworkRequests(operation: Int) async {
        let transport = ContractTransport()
        let client = APIClient(baseURL: server, transport: transport, credentials: MemoryCredentials())
        let repository = APIItemRepository(client: client)
        await #expect(throws: ItemMutationError.notAvailable) {
            switch operation {
            case 0: _ = try await repository.createItem(title: "New", itemType: "task")
            case 1: _ = try await repository.completeItem(id: UUID(), updatedAt: "revision")
            case 2: _ = try await repository.reopenItem(id: UUID(), updatedAt: "revision")
            default: try await repository.deleteItem(id: UUID(), updatedAt: "revision")
            }
        }
        #expect(transport.requests.isEmpty)
    }

    @Test func titlePatchSendsCorrectMethodPathAndExactBody() async throws {
        let itemID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let transport = ContractTransport()
        let store = MemoryCredentials()
        store.credential = SessionCredential(token: "test-token", expiresAt: .distantFuture)
        let client = APIClient(baseURL: server, transport: transport, credentials: store)
        let repository = APIItemRepository(client: client)

        transport.handler = { request in
            #expect(request.httpMethod == "PATCH")
            #expect(request.url?.path == "/api/v1/items/\(itemID.uuidString.lowercased())")
            #expect(request.value(forHTTPHeaderField: "Cookie") == "session=test-token")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
            let httpBody = try #require(request.httpBody)
            let bodyJSON = try #require(try JSONSerialization.jsonObject(with: httpBody) as? [String: Any])
            #expect(bodyJSON["title"] as? String == "Updated Title")
            #expect(bodyJSON["expectedRevision"] as? Int == 3)
            #expect(bodyJSON.count == 2)
            #expect(bodyJSON["updatedAt"] == nil)
            #expect(bodyJSON["metadata"] == nil)
            #expect(bodyJSON["status"] == nil)
            #expect(bodyJSON["dueDate"] == nil)
            #expect(bodyJSON["itemType"] == nil)
            return self.response("""
            {"item":{"id":"\(itemID.uuidString.lowercased())","title":"Updated Title",
            "status":"active","itemType":"task","dueDate":null,"metadata":{"userEdited":true},
            "revision":4,"updatedAt":"2026-11-17T20:30:00.000Z"}}
            """)
        }

        let updated = try await repository.updateItem(id: itemID, title: "Updated Title", expectedRevision: 3)
        #expect(updated.id == itemID)
        #expect(updated.title == "Updated Title")
        #expect(updated.revision == 4)
        #expect(updated.updatedAt == "2026-11-17T20:30:00.000Z")
        #expect(updated.metadata["userEdited"] == .bool(true))
    }

    @Test(arguments: [0, -1, -5])
    func titlePatchRejectsInvalidRevisionBeforeNetworkRequest(revision: Int) async {
        let transport = ContractTransport()
        let store = MemoryCredentials()
        store.credential = SessionCredential(token: "test-token", expiresAt: .distantFuture)
        let client = APIClient(baseURL: server, transport: transport, credentials: store)
        let repository = APIItemRepository(client: client)

        await #expect(throws: ItemMutationError.invalidRevision) {
            try await repository.updateItem(id: UUID(), title: "Title", expectedRevision: revision)
        }
        #expect(transport.requests.isEmpty)
    }

    @Test func titlePatchRejectsMalformedSuccessResponse() async {
        let itemID = UUID()
        let transport = ContractTransport()
        let store = MemoryCredentials()
        store.credential = SessionCredential(token: "test-token", expiresAt: .distantFuture)
        let client = APIClient(baseURL: server, transport: transport, credentials: store)
        let repository = APIItemRepository(client: client)

        transport.handler = { _ in self.response("{\"item\":{}}") }
        await #expect(throws: APIError.invalidResponse) {
            try await repository.updateItem(id: itemID, title: "Title", expectedRevision: 1)
        }
    }

    @Test func titlePatchRejectsMismatchedIDSuccessResponse() async {
        let itemID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let differentID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let transport = ContractTransport()
        let store = MemoryCredentials()
        store.credential = SessionCredential(token: "test-token", expiresAt: .distantFuture)
        let client = APIClient(baseURL: server, transport: transport, credentials: store)
        let repository = APIItemRepository(client: client)

        transport.handler = { _ in
            self.response("""
            {"item":{"id":"\(differentID.uuidString.lowercased())","title":"Title",
            "status":"active","itemType":"task","revision":2,"updatedAt":"now"}}
            """)
        }
        await #expect(throws: APIError.invalidResponse) {
            try await repository.updateItem(id: itemID, title: "Title", expectedRevision: 1)
        }
    }

    @Test func titlePatchRejectsNonAdvancingRevisionSuccessResponse() async {
        let itemID = UUID()
        let transport = ContractTransport()
        let store = MemoryCredentials()
        store.credential = SessionCredential(token: "test-token", expiresAt: .distantFuture)
        let client = APIClient(baseURL: server, transport: transport, credentials: store)
        let repository = APIItemRepository(client: client)

        transport.handler = { _ in
            self.response("""
            {"item":{"id":"\(itemID.uuidString.lowercased())","title":"Title",
            "status":"active","itemType":"task","revision":1,"updatedAt":"now"}}
            """)
        }
        await #expect(throws: APIError.invalidResponse) {
            try await repository.updateItem(id: itemID, title: "Title", expectedRevision: 1)
        }
    }

    @Test func titlePatchPropagatesHTTP409WithoutAutomaticRetry() async {
        let itemID = UUID()
        let transport = ContractTransport()
        let store = MemoryCredentials()
        store.credential = SessionCredential(token: "test-token", expiresAt: .distantFuture)
        let client = APIClient(baseURL: server, transport: transport, credentials: store)
        let repository = APIItemRepository(client: client)

        transport.handler = { _ in
            self.response("""
            {"error":"Item has been modified by another session","code":"REVISION_CONFLICT","currentRevision":5}
            """, status: 409)
        }
        let error = await #expect(throws: ItemMutationError.self) {
            try await repository.updateItem(id: itemID, title: "Title", expectedRevision: 2)
        }
        #expect(error == .conflict)
        #expect(transport.requests.count == 1)
    }

    @Test func titlePatchPropagatesAuthenticationError() async {
        let itemID = UUID()
        let transport = ContractTransport()
        let store = MemoryCredentials()
        store.credential = SessionCredential(token: "test-token", expiresAt: .distantFuture)
        let client = APIClient(baseURL: server, transport: transport, credentials: store)
        let repository = APIItemRepository(client: client)

        transport.handler = { _ in self.response("{\"error\":\"Unauthorized\"}", status: 401) }
        let error = await #expect(throws: APIError.self) {
            try await repository.updateItem(id: itemID, title: "Title", expectedRevision: 1)
        }
        #expect(error == .unauthorized)
        #expect(transport.requests.count == 1)
    }

    @Test func titlePatchPropagatesNetworkErrorWithoutBlindRetry() async {
        let itemID = UUID()
        let transport = ContractTransport()
        let store = MemoryCredentials()
        store.credential = SessionCredential(token: "test-token", expiresAt: .distantFuture)
        let client = APIClient(baseURL: server, transport: transport, credentials: store)
        let repository = APIItemRepository(client: client)

        transport.handler = { _ in throw URLError(.networkConnectionLost) }
        await #expect(throws: URLError.self) {
            try await repository.updateItem(id: itemID, title: "Title", expectedRevision: 1)
        }
        #expect(transport.requests.count == 1)
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

    @Test func organizerCapabilitiesSeparation() {
        let none = OrganizerCapabilities.none
        #expect(!none.allowsTitleEditing)
        #expect(!none.allowsItemMutations)

        let titleOnly = OrganizerCapabilities.titleOnly
        #expect(titleOnly.allowsTitleEditing)
        #expect(!titleOnly.allowsItemMutations)

        let demo = OrganizerCapabilities.demo
        #expect(demo.allowsTitleEditing)
        #expect(demo.allowsItemMutations)

        let legacyDisabled = OrganizerCapabilities(allowsEditing: false)
        #expect(!legacyDisabled.allowsTitleEditing)
        #expect(!legacyDisabled.allowsItemMutations)

        let legacyEnabled = OrganizerCapabilities(allowsEditing: true)
        #expect(legacyEnabled.allowsTitleEditing)
        #expect(legacyEnabled.allowsItemMutations)
    }

    @Test func draftPersistencePreservesIntegerRevisionAndLegacyJSON() throws {
        let draft = ItemDraft(title: "New Draft", baseRevision: "2026-11-14T00:00:00.000Z", baseItemRevision: 4)
        let encoded = try JSONEncoder().encode(draft)
        let decoded = try JSONDecoder().decode(ItemDraft.self, from: encoded)
        #expect(decoded.title == "New Draft")
        #expect(decoded.baseItemRevision == 4)
        #expect(decoded.baseRevision == "2026-11-14T00:00:00.000Z")

        // Legacy draft without baseItemRevision must decode without error and leave baseItemRevision nil
        let legacyJSON = "{\"title\":\"Legacy\",\"baseRevision\":\"2026-11-14T00:00:00.000Z\"}".data(using: .utf8)!
        let legacyDecoded = try JSONDecoder().decode(ItemDraft.self, from: legacyJSON)
        #expect(legacyDecoded.title == "Legacy")
        #expect(legacyDecoded.baseRevision == "2026-11-14T00:00:00.000Z")
        #expect(legacyDecoded.baseItemRevision == nil)
    }

    @Test func accountLocalStoreDraftScopingAndPurge() throws {
        let container = try AccountLocalStore.makeContainer(inMemory: true)
        let accountA = UUID()
        let accountB = UUID()
        let itemID = UUID()

        let storeA = AccountLocalStore(container: container, server: server, accountID: accountA)
        let storeB = AccountLocalStore(container: container, server: server, accountID: accountB)

        let draft = ItemDraft(title: "Account A Draft", baseItemRevision: 3)
        try storeA.saveDraft(draft, itemID: itemID)

        #expect(try storeA.draft(itemID: itemID)?.title == "Account A Draft")
        #expect(try storeA.draft(itemID: itemID)?.baseItemRevision == 3)
        // Store B must never see Store A's draft
        #expect(try storeB.draft(itemID: itemID) == nil)

        // Purging store A cleans up and invalidates
        try storeA.purgeAndInvalidate()
        #expect(throws: CancellationError.self) {
            _ = try storeA.draft(itemID: itemID)
        }
        #expect(try storeB.draft(itemID: itemID) == nil)
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
