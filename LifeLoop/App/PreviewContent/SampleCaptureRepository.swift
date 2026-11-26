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
}
