import Foundation
import Testing
@testable import LifeLoop

@MainActor
struct CaptureContractTests {
    private let server = URL(string: "https://staging.example.com")!

    @Test func createCaptureSendsCorrectJSON() async throws {
        let transport = CaptureTestTransport()
        let store = CaptureTestCredentials()
        store.credential = SessionCredential(
            token: "test-session-token",
            expiresAt: Date().addingTimeInterval(3600)
        )
        let client = APIClient(baseURL: server, transport: transport, credentials: store)
        let repository = APICaptureRepository(client: client)

        transport.handler = { request in
            #expect(request.url?.path == "/api/v1/captures")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Content-Type")?.contains("application/json") == true)
            #expect(request.value(forHTTPHeaderField: "Cookie") == "session=test-session-token")
            #expect(request.value(forHTTPHeaderField: "X-Timezone") == TimeZone.current.identifier)

            let body = try JSONDecoder().decode([String: String].self, from: #require(request.httpBody))
            #expect(body["type"] == "text")
            #expect(body["source"] == "ios")
            #expect(body["rawPayload"] == "Pay electricity bill tomorrow and renew car insurance next month")

            let responseJSON = """
            {
                "capture": {
                    "id": "11111111-2222-3333-4444-555555555555",
                    "source": "ios",
                    "type": "text",
                    "rawPayload": "Pay electricity bill tomorrow and renew car insurance next month",
                    "processingStatus": "pending",
                    "createdAt": "2026-11-22T10:00:00.000Z"
                }
            }
            """
            return self.response(responseJSON, status: 201)
        }

        let capture = try await repository.createCapture(
            text: "Pay electricity bill tomorrow and renew car insurance next month",
            source: "ios"
        )

        #expect(capture.id == UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        #expect(capture.source == "ios")
        #expect(capture.type == "text")
        #expect(capture.processingStatus == .pending)
        #expect(capture.previewText == "Pay electricity bill tomorrow and renew car insurance next month")
    }

    @Test func createCaptureRejectsEmptyAndWhitespaceInput() async {
        let transport = CaptureTestTransport()
        let store = CaptureTestCredentials()
        let client = APIClient(baseURL: server, transport: transport, credentials: store)
        let repository = APICaptureRepository(client: client)

        await #expect(throws: CaptureValidationError.empty) {
            _ = try await repository.createCapture(text: "")
        }

        await #expect(throws: CaptureValidationError.empty) {
            _ = try await repository.createCapture(text: "   \n\t  ")
        }

        #expect(transport.requests.isEmpty)
    }

    @Test func createCaptureRejectsOverLimitInput() async {
        let transport = CaptureTestTransport()
        let store = CaptureTestCredentials()
        let client = APIClient(baseURL: server, transport: transport, credentials: store)
        let repository = APICaptureRepository(client: client)

        let overLimitText = String(repeating: "a", count: 10_001)

        await #expect(throws: CaptureValidationError.tooLong(10_001)) {
            _ = try await repository.createCapture(text: overLimitText)
        }

        #expect(transport.requests.isEmpty)
    }

    @Test func createCaptureEnforcesUTF16LengthMatchingBackend() async throws {
        let transport = CaptureTestTransport()
        let store = CaptureTestCredentials()
        store.credential = SessionCredential(
            token: "test-token",
            expiresAt: Date().addingTimeInterval(3600)
        )
        let client = APIClient(baseURL: server, transport: transport, credentials: store)
        let repository = APICaptureRepository(client: client)

        // An emoji like "😀" is 1 Swift character (String.count == 1), but 2 UTF-16 code units (utf16.count == 2).
        let emoji = "😀"
        #expect(emoji.count == 1)
        #expect(emoji.utf16.count == 2)

        // 5001 emojis = 5001 String.count, but 10,002 UTF-16 code units (> 10,000 limit)
        let overLimitEmojis = String(repeating: emoji, count: 5001)
        #expect(overLimitEmojis.count == 5001)
        #expect(overLimitEmojis.utf16.count == 10_002)

        await #expect(throws: CaptureValidationError.tooLong(10_002)) {
            _ = try await repository.createCapture(text: overLimitEmojis)
        }
        #expect(transport.requests.isEmpty)

        // Exactly 5000 emojis = 10,000 UTF-16 code units (boundary limit - allowed)
        let maxEmojis = String(repeating: emoji, count: 5000)
        #expect(maxEmojis.utf16.count == 10_000)

        transport.handler = { _ in
            let responseJSON = """
            {
                "capture": {
                    "id": "11111111-2222-3333-4444-555555555555",
                    "source": "ios",
                    "type": "text",
                    "rawPayload": "\(maxEmojis)",
                    "processingStatus": "pending",
                    "createdAt": "2026-11-22T10:00:00.000Z"
                }
            }
            """
            return self.response(responseJSON, status: 201)
        }

        let capture = try await repository.createCapture(text: maxEmojis)
        #expect(capture.rawPayload == maxEmojis)
    }

    @Test func fetchCapturesSendsGETRequestAndDecodesList() async throws {
        let transport = CaptureTestTransport()
        let store = CaptureTestCredentials()
        store.credential = SessionCredential(
            token: "test-token",
            expiresAt: Date().addingTimeInterval(3600)
        )
        let client = APIClient(baseURL: server, transport: transport, credentials: store)
        let repository = APICaptureRepository(client: client)

        transport.handler = { request in
            #expect(request.url?.path == "/api/v1/captures")
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "Cookie") == "session=test-token")

            let responseJSON = """
            {
                "captures": [
                    {
                        "id": "22222222-2222-2222-2222-222222222222",
                        "source": "ios",
                        "type": "text",
                        "rawPayload": "Buy groceries tomorrow",
                        "processingStatus": "processing",
                        "createdAt": "2026-11-22T11:00:00.000Z"
                    },
                    {
                        "id": "11111111-1111-1111-1111-111111111111",
                        "source": "web",
                        "type": "text",
                        "rawPayload": "Doctor appointment",
                        "processingStatus": "completed",
                        "createdAt": "2026-11-22T09:00:00.000Z"
                    }
                ]
            }
            """
            return self.response(responseJSON, status: 200)
        }

        let captures = try await repository.fetchCaptures()
        #expect(captures.count == 2)
        #expect(captures[0].id == UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        #expect(captures[0].processingStatus == .processing)
        #expect(captures[0].source == "ios")
        #expect(captures[1].id == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(captures[1].processingStatus == .completed)
        #expect(captures[1].source == "web")
    }

    @Test func decodesAllProcessingStatusesIncludingUnknown() {
        #expect(CaptureProcessingStatus(rawValue: "pending") == .pending)
        #expect(CaptureProcessingStatus(rawValue: "processing") == .processing)
        #expect(CaptureProcessingStatus(rawValue: "completed") == .completed)
        #expect(CaptureProcessingStatus(rawValue: "failed") == .failed)
        #expect(CaptureProcessingStatus(rawValue: "fallback_pending_retry") == .fallbackPendingRetry)
        #expect(CaptureProcessingStatus(rawValue: "future_ai_status") == .unknown("future_ai_status"))

        // Active vs terminal checks
        #expect(CaptureProcessingStatus.pending.isActive)
        #expect(CaptureProcessingStatus.processing.isActive)
        #expect(CaptureProcessingStatus.fallbackPendingRetry.isActive)
        #expect(!CaptureProcessingStatus.completed.isActive)
        #expect(!CaptureProcessingStatus.failed.isActive)
        #expect(!CaptureProcessingStatus.unknown("future").isActive)
    }

    @Test func capturePreviewTextExtractsFirstLineAndTrims() {
        let multiLine = Capture(
            id: UUID(),
            source: "ios",
            type: "text",
            rawPayload: "   First line of capture\nSecond line\nThird line   ",
            processingStatus: .completed,
            createdAt: Date()
        )
        #expect(multiLine.previewText == "First line of capture")

        let singleLine = Capture(
            id: UUID(),
            source: "ios",
            type: "text",
            rawPayload: "   Single line only   ",
            processingStatus: .completed,
            createdAt: Date()
        )
        #expect(singleLine.previewText == "Single line only")
    }

    private func response(_ json: String, status: Int = 200, headers: [String: String] = [:]) -> (Data, HTTPURLResponse) {
        (Data(json.utf8), HTTPURLResponse(url: server, statusCode: status, httpVersion: nil, headerFields: headers)!)
    }
}

@MainActor
private final class CaptureTestCredentials: SessionCredentialStore {
    var credential: SessionCredential?
    func read() throws -> SessionCredential? { credential }
    func save(_ credential: SessionCredential) throws { self.credential = credential }
    func clear() throws { credential = nil }
}

@MainActor
private final class CaptureTestTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var handler: ((URLRequest) async throws -> (Data, HTTPURLResponse))?
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let respond = try #require(handler)
        return try await respond(request)
    }
}
