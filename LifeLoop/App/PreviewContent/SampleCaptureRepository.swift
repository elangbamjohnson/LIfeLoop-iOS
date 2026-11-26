//
//  SampleCaptureRepository.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 22/11/26.
//

import Foundation

@MainActor
final class SampleCaptureRepository: CaptureRepository {
    var captures: [Capture]
    var shouldFail: Bool = false
    var failNextSubmission = false
    var shouldFailMutation = false

    init(captures: [Capture]? = nil) {
        if let captures {
            self.captures = captures
        } else {
            self.captures = [
                Capture(
                    id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                    source: "ios",
                    type: "text",
                    rawPayload: "Pay electricity bill tomorrow and renew car insurance next month",
                    processingStatus: .completed,
                    createdAt: Date().addingTimeInterval(-3600)
                ),
                Capture(
                    id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                    source: "ios",
                    type: "text",
                    rawPayload: "Dentist appointment with Dr. Smith next Friday at 3pm",
                    processingStatus: .processing,
                    createdAt: Date().addingTimeInterval(-60)
                ),
                Capture(
                    id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
                    source: "ios",
                    type: "text",
                    rawPayload: "Renew passport before summer trip",
                    processingStatus: .completed,
                    metadata: ["aiEnrichmentFailed": .bool(true)],
                    createdAt: Date().addingTimeInterval(-7200)
                )
            ]
        }
    }

    func createCapture(text: String, source: String = "ios") async throws -> Capture {
        if failNextSubmission {
            failNextSubmission = false
            throw APIError.server(500)
        }
        if shouldFail { throw APIError.server(500) }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CaptureValidationError.empty }

        let utf16Count = text.utf16.count
        guard utf16Count <= 10_000 else { throw CaptureValidationError.tooLong(utf16Count) }

        let capture = Capture(
            id: UUID(),
            source: source,
            type: "text",
            rawPayload: text,
            processingStatus: .pending,
            createdAt: Date()
        )
        captures.insert(capture, at: 0)
        return capture
    }

    func fetchCaptures() async throws -> [Capture] {
        if shouldFail { throw APIError.server(500) }
        return captures
    }

    func retryCapture(id: UUID) async throws {
        if shouldFail || shouldFailMutation { throw APIError.server(500) }
        guard let index = captures.firstIndex(where: { $0.id == id }) else {
            throw APIError.server(404)
        }
        var updatedMetadata = captures[index].metadata
        updatedMetadata["aiEnrichmentFailed"] = .bool(false)
        updatedMetadata.removeValue(forKey: "lastRetryError")
        captures[index] = Capture(
            id: captures[index].id,
            source: captures[index].source,
            type: captures[index].type,
            rawPayload: captures[index].rawPayload,
            originalFilename: captures[index].originalFilename,
            mimeType: captures[index].mimeType,
            processingStatus: .fallbackPendingRetry,
            retryCount: 0,
            metadata: updatedMetadata,
            createdAt: captures[index].createdAt,
            updatedAt: Date()
        )
    }

    func deleteCapture(id: UUID) async throws {
        if shouldFail || shouldFailMutation { throw APIError.server(500) }
        guard let index = captures.firstIndex(where: { $0.id == id }) else {
            throw APIError.server(404)
        }
        captures.remove(at: index)
    }
}
